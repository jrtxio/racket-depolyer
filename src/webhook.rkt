#lang racket

(require web-server/http
         web-server/servlet
         json
         "config.rkt"
         "git.rkt"
         "build.rkt")

(provide handle-webhook)

;; Global deployment lock to prevent concurrent builds
(define deploying? (make-semaphore 1))

;; Last build information
(define last-build (make-hash))

;; Compute HMAC-SHA256 signature using openssl
;; Optimized: use pipe instead of temporary file
(define (hmac-sha256 key data)
  (string-trim
   (with-output-to-string
     (lambda ()
       (with-input-from-string data
         (lambda ()
           (system (format "openssl dgst -sha256 -hmac '~a' | awk '{print $2}'" key))))))))

;; Verify GitHub webhook signature
(define (verify-signature payload sig)
  (and sig
       (string=? sig
                 (string-append "sha256=" (hmac-sha256 (cfg-github-secret) payload)))))

;; Get header value from request headers
(define (get-header headers key)
  (define pair (assq key headers))
  (if pair (cdr pair) #f))

;; Log webhook information from payload
(define (log-webhook-info payload)
  (with-handlers ([exn:fail? void])
    (define data (string->jsexpr payload))
    (define repo (hash-ref (hash-ref data 'repository #hash()) 'full_name "unknown"))
    (define pusher (hash-ref (hash-ref data 'pusher #hash()) 'name "unknown"))
    (define commit (hash-ref (hash-ref data 'head_commit #hash()) 'id "unknown"))
    (printf "Repo: ~a\n" repo)
    (printf "Pusher: ~a\n" pusher)
    (printf "Commit: ~a\n" (substring commit 0 (min 7 (string-length commit))))))

;; Deploy in background thread
(define (deploy-async)
  (thread (lambda ()
            (if (semaphore-try-wait? deploying?)
                (dynamic-wind
                  void
                  (lambda ()
                    (sleep 0.1)
                    
                    ;; Record build start
                    (hash-set! last-build 'status "building")
                    (hash-set! last-build 'start-time (current-seconds))
                    
                    ;; Pull latest code
                    (define pull-ok? (pull-repo (cfg-repo-path)))
                    
                    ;; Check if node_modules exists (first deployment)
                    (define node-modules (build-path (cfg-repo-path) "node_modules"))
                    (unless (directory-exists? node-modules)
                      (printf "First deployment, installing dependencies...\n")
                      (install-dependencies (cfg-repo-path)))
                    
                    ;; Build site
                    (with-handlers ([exn:fail? 
                                    (lambda (e)
                                      (printf "Build error: ~a\n" (exn-message e))
                                      (hash-set! last-build 'status "failed")
                                      (hash-set! last-build 'error (exn-message e)))])
                      (define build-ok? (build-site (cfg-repo-path)))
                      
                      ;; Record build result
                      (if build-ok?
                          (begin
                            (hash-set! last-build 'status "success")
                            (hash-set! last-build 'end-time (current-seconds)))
                          (hash-set! last-build 'status "failed"))))
                  (lambda ()
                    (semaphore-post deploying?)))
                (printf "⚠ Build already in progress, skipping...\n")))))

;; Handle webhook requests
(define (handle-webhook req)
  (define method (request-method req))
  (define headers (request-headers req))
  (define path (url-path (request-uri req)))
  
  (cond
    ;; GET /health - Health check endpoint
    [(and (bytes=? method #"GET")
          (equal? path (list (path/param "health" '()))))
     (define status (hash-ref last-build 'status "idle"))
     (response/output
      (lambda (out)
        (fprintf out "Status: ~a\n" status)
        (when (hash-has-key? last-build 'end-time)
          (fprintf out "Last build: ~a seconds ago\n"
                  (- (current-seconds) (hash-ref last-build 'end-time))))))]
    
    ;; GET / - Basic status
    [(bytes=? method #"GET")
     (response/output
      (lambda (out)
        (fprintf out "Blog Deploy Webhook\nStatus: Running\n")))]
    
    ;; POST / - Webhook handler
    [(bytes=? method #"POST")
     (define payload (bytes->string/utf-8 (request-post-data/raw req)))
     (define signature (get-header headers 'x-hub-signature-256))
     (define event (get-header headers 'x-github-event))
     
     (printf "\n=== Webhook received ===\n")
     (printf "Event: ~a\n" event)
     (printf "Payload size: ~a bytes\n" (string-length payload))
     
     ;; Verify signature
     (if (verify-signature payload signature)
         (begin
           (printf "✓ Signature verified\n")
           
           ;; Log webhook information
           (log-webhook-info payload)
           
           (printf "======================\n")
           
           ;; Deploy asynchronously
           (deploy-async)
           
           ;; Return immediately
           (response/output
            (lambda (out)
              (fprintf out "Webhook accepted\n"))))
         
         ;; Invalid signature
         (begin
           (printf "✗ Invalid signature\n")
           (printf "======================\n")
           (response/output
            #:code 401
            (lambda (out)
              (fprintf out "Unauthorized\n")))))]
    
    ;; Other methods
    [else
     (response/output
      #:code 405
      (lambda (out)
        (fprintf out "Method not allowed\n")))]))