#lang racket

(require web-server/servlet-env
         web-server/servlet
         web-server/http
         web-server/http/response
         "src/config.rkt"
         "src/webhook.rkt"
         "src/build.rkt")

;; Main program
(define (main)
  ;; Load configuration
  (load-config)
  
  ;; Check build tools at startup
  (unless (check-tools)
    (error "Build tools not available. Please install Node.js and npm."))
  
  ;; Display startup information
  (printf "\n")
  (printf "========================================\n")
  (printf "  Blog Deploy Webhook Server\n")
  (printf "========================================\n")
  (printf "Port: ~a\n" (cfg-port))
  (printf "Repo: ~a\n" (cfg-repo-path))
  (printf "========================================\n")
  (printf "\n")
  
  ;; Define servlet handler with error handling
  (define servlet-handler
    (lambda (req)
      (with-handlers ([exn:fail:network?
                       (lambda (e)
                         (printf "Network error: ~a\n" (exn-message e))
                         (response/output #:code 500 
                           (lambda (out) 
                             (fprintf out "Internal Server Error\n"))))]
                      [exn:fail?
                       (lambda (e)
                         (unless (string-contains? (exn-message e) "output port is closed")
                           (printf "Error: ~a\n" (exn-message e)))
                         (with-handlers ([exn:fail? void])
                           (response/output #:code 500 
                             (lambda (out) 
                               (fprintf out "Internal Server Error\n")))))])
        (handle-webhook req))))
  
  ;; Start HTTP server (HTTPS handled by Nginx)
  (printf "Starting HTTP server on port ~a...\n" (cfg-port))
  (printf "Listening on 127.0.0.1 (use Nginx for public access)\n")
  (serve/servlet servlet-handler
                 #:port (cfg-port)
                 #:listen-ip "127.0.0.1"  ; Listen on localhost only
                 #:servlet-path "/"
                 #:servlet-regexp #rx""
                 #:launch-browser? #f))

;; Run
(module+ main
  (main))