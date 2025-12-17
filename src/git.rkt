#lang racket

(provide is-git-repo?
         clone-repo
         pull-repo)

;; Check if path is a git repository
(define (is-git-repo? path)
  (and (directory-exists? path)
       (directory-exists? (build-path path ".git"))))

;; Clone repository from URL to path
(define (clone-repo url path)
  (cond
    [(directory-exists? path)
     (printf "Repository already exists at ~a\n" path)
     #t]
    [else
     (printf "Cloning from ~a...\n" url)
     (system (format "git clone ~a ~a" url path))]))

;; Pull latest changes from repository (with retry logic)
(define (pull-repo path [retries 3])
  (if (not (is-git-repo? path))
      (begin
        (printf "✗ Not a git repository: ~a\n" path)
        #f)
      (let loop ([attempt 1])
        (if (> attempt retries)
            (begin
              (printf "✗ Pull failed after ~a attempts\n" retries)
              #f)
            (begin
              (printf "Pulling latest changes (attempt ~a/~a)...\n" attempt retries)
              (if (parameterize ([current-directory path])
                    (system "git pull origin main 2>&1"))
                  (begin
                    (printf "✓ Pull completed\n")
                    #t)
                  (begin
                    (printf "⚠ Pull failed, retrying in 2 seconds...\n")
                    (sleep 2)
                    (loop (+ attempt 1)))))))))