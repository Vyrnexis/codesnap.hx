(require-builtin steel/filesystem)
(require "codesnap-core.scm")
(require "codesnap-process.scm")

(provide config-file-path read-config-file write-config-file)

;; Locates the settings file: CODESNAP_CONFIG, then Helix's configuration directory.
(define (config-file-path)
  (or (environment-value "CODESNAP_CONFIG")
      (let ([xdg (environment-value "XDG_CONFIG_HOME")]
            [appdata (environment-value "APPDATA")]
            [home (or (environment-value "HOME") (environment-value "USERPROFILE"))])
        (cond
          [(and xdg (not (string=? xdg ""))) (string-append xdg "/helix/codesnap.toml")]
          [(and appdata (not (is-dir? (string-append (or home "") "/.config/helix"))))
           (string-append appdata "/helix/codesnap.toml")]
          [home (string-append home "/.config/helix/codesnap.toml")]
          [else #f]))))

;; Returns parsed settings, or false when no readable file exists.
(define (read-config-file)
  (let ([path (config-file-path)])
    (and path (is-file? path)
         (with-handler
          (lambda (err)
            (hash 'entries '()
                  'warnings (list (string-append "cannot read " path ": " (to-string err)))))
          (parse-config-text (call-with-input-file path read-port-to-string))))))

;; Writes settings through a temporary file so a failed write keeps the previous file.
(define (write-config-file entries)
  (let ([path (config-file-path)])
    (when (not path) (error "no Helix configuration directory could be determined"))
    (create-directory! (parent-name path))
    (let ([staging (string-append path ".tmp")])
      (let ([port (open-output-file staging #:exists 'truncate)])
        (display (config->text entries) port)
        (close-output-port port))
      (rename-file-or-directory! staging path))
    path))
