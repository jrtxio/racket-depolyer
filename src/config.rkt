#lang racket

(require json)

(provide load-config
         cfg-github-secret
         cfg-port
         cfg-repo-path
         cfg-repo-url
         cfg-build-output
         cfg-deploy-enabled?
         cfg-deploy-remote-host
         cfg-deploy-remote-path
         cfg-deploy-ssh-key
         cfg-deploy-rsync-options)

;; Global configuration hash
(define config (make-hash))

;; Load configuration from JSON file
(define (load-config [file "config.json"])
  (if (file-exists? file)
      (begin
        (set! config (with-input-from-file file read-json))
        (printf "✓ Config loaded from ~a\n" file))
      (error "Config file not found: ~a" file)))

;; Get configuration value with optional default
(define (get-config key [default #f])
  (hash-ref config key default))

;; Configuration accessors
(define (cfg-github-secret) (get-config 'github-secret))
(define (cfg-port) (get-config 'port 8080))
(define (cfg-repo-path) (get-config 'repo-path))
(define (cfg-repo-url) (get-config 'repo-url))
(define (cfg-build-output) (get-config 'build-output))

;; Deploy configuration accessors
(define (cfg-deploy-enabled?)
  (define deploy (get-config 'deploy #hash()))
  (and (hash? deploy)
       (hash-ref deploy 'enabled #f)))

(define (cfg-deploy-remote-host)
  (define deploy (get-config 'deploy #hash()))
  (and (hash? deploy)
       (hash-ref deploy 'remote-host #f)))

(define (cfg-deploy-remote-path)
  (define deploy (get-config 'deploy #hash()))
  (and (hash? deploy)
       (hash-ref deploy 'remote-path #f)))

(define (cfg-deploy-ssh-key)
  (define deploy (get-config 'deploy #hash()))
  (and (hash? deploy)
       (hash-ref deploy 'ssh-key #f)))

(define (cfg-deploy-rsync-options)
  (define deploy (get-config 'deploy #hash()))
  (if (and (hash? deploy)
           (hash-has-key? deploy 'rsync-options))
      (hash-ref deploy 'rsync-options)
      "-avz --delete"))