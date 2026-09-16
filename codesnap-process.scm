(require-builtin steel/process)
(require-builtin steel/random)
(require "codesnap-core.scm")

(provide run-program render-success? render-error-message render-with-fallback
         render-file with-temporary-file environment-value absolute-path)

;; Reads an optional environment variable without raising when it is absent.
(define (environment-value name)
  (with-handler (lambda (_) #f) (env-var name)))

;; Expands the current user's home and resolves paths before worker threads start.
(define (absolute-path path)
  (let* ([home (or (environment-value "HOME") (environment-value "USERPROFILE"))]
         [expanded (cond
                     [(and home (equal? path "~")) home]
                     [(and home (or (starts-with? path "~/") (starts-with? path "~\\")))
                      (string-append home (substring path 1 (string-length path)))]
                     [else path])])
    (if (or (starts-with? expanded "/") (starts-with? expanded "\\")
            (and (> (string-length expanded) 2) (char=? (string-ref expanded 1) #\:)))
        expanded
        (string-append (current-directory) "/" expanded))))

;; Creates an exclusive temporary file and removes it after success or failure.
(define (with-temporary-file action #:directory [directory #f] #:suffix [suffix ".log"])
  (let* ([directory (or directory
                        (environment-value "TMPDIR") (environment-value "TEMP")
                        (environment-value "TMP")
                        (if (is-dir? "/tmp") "/tmp" (current-directory)))]
         [path (string-append (absolute-path directory) "/.codesnap-"
                              (number->string (rng->gen-usize)) suffix)]
         [port (open-output-file path #:exists 'error)])
    (dynamic-wind
     (lambda () void)
     (lambda () (action path port))
     (lambda ()
       (when (output-port? port) (close-output-port port))
       (when (path-exists? path) (delete-file! path))))))

;; Runs a direct subprocess with isolated Silicon settings and finite diagnostic reads.
(define (run-program program args stdin-input)
  (with-handler
   (lambda (err) (hash 'stdout "" 'stderr (to-string err) 'exit #f))
   (with-temporary-file
    (lambda (config-path config-port)
      (close-output-port config-port)
      (with-temporary-file
       (lambda (stdout-path stdout-port)
         (with-temporary-file
          (lambda (stderr-path stderr-port)
            (let* ([spawned
                    (let ([cmd (command program args)])
                      (when (equal? program "silicon")
                        (with-env-var cmd "SILICON_CONFIG_PATH" config-path))
                      (with-stdin-piped cmd)
                      (with-stdout cmd stdout-port)
                      (with-stderr cmd stderr-port)
                      (spawn-process cmd))])
              (if (Err? spawned)
                  (hash 'stdout "" 'stderr (to-string (Err->value spawned)) 'exit #f)
                  (let* ([child (Ok->value spawned)]
                         [stdin (child-stdin child)]
                         [input-error
                          (with-handler
                           (lambda (err) (to-string err))
                           (when (string? stdin-input) (display stdin-input stdin))
                           #f)]
                         [close-error (with-handler (lambda (err) (to-string err))
                                        (close-output-port stdin) #f)]
                         [wait-result (wait child)]
                         [stdout (call-with-input-file stdout-path read-port-to-string)]
                         [stderr (call-with-input-file stderr-path read-port-to-string)])
                    (hash 'stdout stdout
                          'stderr (if (and (or input-error close-error) (string=? (trim stderr) ""))
                                      (or input-error close-error) stderr)
                          'exit (if (Ok? wait-result) (Ok->value wait-result) #f)))))))))))))

;; Checks both status and diagnostics because Silicon reports some errors with exit zero.
(define (render-success? result)
  (and (equal? (hash-ref result 'exit) 0)
       (string=? (trim (hash-ref result 'stderr)) "")))

;; Keeps the actual diagnostic, including spawn and stdin errors, in the status message.
(define (render-error-message result)
  (let ([stderr (trim (hash-ref result 'stderr))])
    (cond
      [(not (string=? stderr "")) (car (split-many stderr "\n"))]
      [(not (hash-ref result 'exit)) "Unable to run the requested program"]
      [else (string-append "Process exited with status "
                           (number->string (hash-ref result 'exit)))])))

;; Retries only unsupported syntaxes, including clipboard invocations.
(define (render-with-fallback selection attempts)
  (let* ([result (run-program "silicon" (car attempts) selection)])
    (if (and (not (render-success? result))
             (unsupported-language-error? (hash-ref result 'stderr))
             (pair? (cdr attempts)))
        (render-with-fallback selection (cdr attempts))
        result)))

;; Publishes a completed render atomically, reserving new destinations without overwriting.
(define (render-file selection make-attempts path replace?)
  (with-handler
   (lambda (err) (hash 'stdout "" 'stderr (to-string err) 'exit #f))
   (with-temporary-file
    (lambda (staging port)
      (close-output-port port)
      (let ([result (render-with-fallback selection (make-attempts staging))])
        (if (render-success? result)
          (let ([reserved? #f])
            (with-handler
             (lambda (err)
               (when reserved? (delete-file! path))
               (hash 'stdout "" 'stderr (to-string err) 'exit #f))
             (when (not replace?)
               (close-output-port (open-output-file path #:exists 'error))
               (set! reserved? #t))
             (rename-file-or-directory! staging path)
             result))
          result)))
    #:directory (parent-name path)
    #:suffix (string-append "." (or (path-extension path) "png")))))
