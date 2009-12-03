;;; slashdot.el --- View and browse headlines captured with slashcache.lisp.
;; Copyright 2001 by Dave Pearson <davep@davep.org>
;; $Revision: 1.6 $

;; slashdot.el is free software distributed under the terms of the GNU General
;; Public Licence, version 2. For details see the file COPYING.

;;; Commentary:
;;
;; This package provides a method of reading the slashdot headlines captured
;; with slashcache.lisp <URL:http://www.davep.org/lisp/slashcache.lisp> and
;; firing off a browser for reading the full article.

(eval-when-compile
  (require 'cl))

(defvar slashdot-headline-database "~/.slashdot-headlines"
  "*Location of the slashdot headline cache/database.")

(defvar slashdot-browse-command #'browse-url
  "*Function that allows you to browse the chosen URL.")

(defvar slashdot-mode-hook nil
  "*Mode hooks.")

(defvar slashdot-format-headline
  #'(lambda (headline)
      (format "%s - %s"
              (current-time-string (ninth headline))
              (first headline)))
  "*Code to format a headline for display in the headline buffer.")

(defvar slashdot-buffer "*slashdot-headlines*"
  "Name of the slashdot selection buffer.")

(defvar slashdot-mode-map nil
  "Local keymap for the `slashdot-headlines' buffer.")

(defvar slashdot-headlines nil
  "Current slashdot headlines.")

(defvar slashdot-last-buffer nil
  "Pointer to the buffer we should return to.")

(unless slashdot-mode-map
  (let ((map (make-sparse-keymap)))
    (suppress-keymap map t)
    (define-key map "\C-m"    #'slashdot-read-story)
    (define-key map "i"       #'slashdot-insert-story)
    (define-key map "u"       #'slashdot-insert-url)
    (define-key map "\C-g"    #'slashdot-quit)
    (define-key map "q"       #'slashdot-quit)
    (define-key map "r"       #'slashdot-refresh-buffer)
    (define-key map [mouse-2] #'slashdot-mouse-select)
    (define-key map "?"       #'describe-mode)
    (setq slashdot-mode-map map)))

(put 'slashdot-mode 'mode-class 'special)

;; Mode functions.

(defun slashdot-mode ()
  "A mode for use with `slashdot-headlines'.

The key bindings for `slashdot-mode' are:

\\{slashdot-mode-map}"
  (interactive)
  (kill-all-local-variables)
  (use-local-map slashdot-mode-map)
  (setq major-mode       'slashdot-mode
        mode-name        "slashdot headlines"
        truncate-lines   t
        buffer-read-only t)
  (run-hooks 'slashdot-mode-hook))

;; Support functions.

(defun slashdot-database ()
  "Load the headline list from `slashdot-headline-database'."
  (if (file-exists-p slashdot-headline-database)
      (with-temp-buffer
        (insert-file-contents slashdot-headline-database t)
        (read (current-buffer)))
    (beep)
    (message "No such file %s" slashdot-headline-database)
    (list)))

(defun slashdot-populate-current-buffer ()
  "Populate the current buffer with headlines."
  (let ((buffer-read-only nil))
    (setf (buffer-string) "")
    (loop for headline in slashdot-headlines
          do (let ((start (point)))
               (insert (format "%s\n" (funcall slashdot-format-headline
                                               (cdr headline))))
               (put-text-property start (1- (point)) 'mouse-face 'highlight)))
    (setf (point) (point-min))))

;; Interactive functions.

;;;###autoload
(defun slashdot-headlines ()
  (interactive)
  (unless (string= (buffer-name) slashdot-buffer)
    (setq slashdot-last-buffer (current-buffer)))
  (pop-to-buffer slashdot-buffer)
  (setq slashdot-headlines (slashdot-database))
  (slashdot-populate-current-buffer)
  (slashdot-mode))

(defun slashdot-refresh-buffer ()
  (interactive)
  (if (string= (buffer-name) slashdot-buffer)
      (progn
        (setq slashdot-headlines (slashdot-database))
        (slashdot-populate-current-buffer))
    (error "Buffer %s isn't the slashdot.org headline buffer" (buffer-name))))
  
(defun slashdot-current-line ()
  "Work out the line number of the current line."
  (save-excursion
    (beginning-of-line)
    (let ((line-point (point)))
      (setf (point) (point-min))
      (loop while (< (point) line-point) sum 1 do (next-line 1)))))

(put 'slashdot-with-current-headline 'lisp-indent-function 1)

(defmacro slashdot-with-current-headline (headline &rest body)
  "Grab the currently highlighted headline and work on it."
  `(let ((,headline (cdr (nth (slashdot-current-line) slashdot-headlines))))
     (if ,headline
         ,@body
       (error "No headline details on that line"))))

(defun slashdot-read-story ()
  "Select and read the story under the cursor."
  (interactive)
  (slashdot-with-current-headline headline
    (let ((url (second headline)))
      (message "Loading %s" url)
      (funcall slashdot-browse-command url))))

(defun slashdot-insert-story ()
  "Insert the details for the currently selected story into the calling buffer."
  (interactive)
  (slashdot-with-current-headline headline
    (with-current-buffer slashdot-last-buffer
      (insert (format "%s <URL:%s>"
                      (first headline)
                      (second headline)))
      (slashdot-quit))))

(defun slashdot-insert-url ()
  "Insert the URL for the current headline into the calling buffer."
  (interactive)
  (slashdot-with-current-headline headline
    (with-current-buffer slashdot-last-buffer
      (insert (format "<URL:%s>" (second headline)))
      (slashdot-quit))))

(defun slashdot-mouse-select (event)
  "Read the story under the mouse click."
  (interactive "e")
  (setf (point) (posn-point (event-end event)))
  (slashdot-read-story))

(defun slashdot-quit ()
  "Close the slashdot headline window."
  (interactive)
  (kill-buffer slashdot-buffer)
  (switch-to-buffer slashdot-last-buffer)
  (delete-other-windows))

(provide 'slashdot)

;;; slashdot.el ends here.
