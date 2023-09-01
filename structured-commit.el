;;; structured-commit.el --- utils for structured git messages -*- lexical-binding: t -*-
;; Author: Bunny Lushington <bunny@bapi.us>
;; Version: 1.0
;; Package-Requires: ()

;;; Commentary:

;; structured-commit aids in the composition of VC messages.
;;
;; I like my commit messages to be in the form specified here:
;;    https://gist.github.com/brianclements/841ea7bffdb01346392c and
;; wanted a convenience method to provide some completion and scope
;; caching.
;;
;; To use, add `structured-commit/write-message' to `git-commit-setup-hook'
;;
;; e.g.
;;
;; (use-package structured-commit
;;   :after magit
;;   :straight '(structured-commit
;;               :type git
;;               :host github
;;               :repo "bunnylushington/structured-commit")
;;   :hook (git-commit-setup . structured-commit/write-message))

(defvar structured-commit/scope-cache
  (expand-file-name "structured-commit.db" user-emacs-directory)
  "DB to cache commit scopes.")

(defvar structured-commit/db nil
  "Sqlite database object.")

(defun structured-commit/database ()
    "Return an open database object."
    (when (or (not (file-exists-p structured-commit/scope-cache))
              (not (sqlitep structured-commit/db)))
      (setq structured-commit/db
            (sqlite-open structured-commit/scope-cache)))
  (structured-commit/create-schema))

;; (structured-commit/database)
;; (structured-commit/save-scope "test-project" "foo")
;; (structured-commit/scopes-for-project "test-project")

(defun structured-commit/project ()
  "The top of the magit worktree.

This value is, I think, the same as the %t value of the
magit-buffer-name-format."
  (file-name-nondirectory
   (directory-file-name default-directory)))

(defun structured-commit/all-types ()
  "The list of potential commit types."
  '(build ci docs feat fix perf refactor test))

(defun structured-commit/write-message ()
  "Help write a structured commit message.

See https://gist.github.com/brianclements/841ea7bffdb01346392c
for details about angular commit structure."
  (interactive)
  (setq-local structured-commit-added-p nil)
  (let ((summary (read-from-minibuffer "Summary (empty to omit): ")))
    (when (not (equal "" summary))
      (let* ((project (structured-commit/project))
             (type
              (completing-read
               "Commit type: "
               (structured-commit/all-types)))
             (scope
              (completing-read
               "Commit scope: "
               (structured-commit/scopes-for-project project))))
        (structured-commit/save-scope project scope)
        (insert (format "%s(%s): %s\n\n" type scope summary))
        (setq-local structured-commit-added-p t)))))

(defun structured-commit/post-git-commit-setup-advice ()
  "Toggle set-buffer-modified-p if structed comment has been added.

This is necessary because the `git-commit-setup-hook' runs before
the buffer modified flag is set to nil.  We want the option of
having the structured comment be the only comment text without
the user having to type extraneous characters."
  (when structured-commit-added-p
    (set-buffer-modified-p t)))

(advice-add 'git-commit-setup :after
            #'structured-commit/post-git-commit-setup-advice)

(defun structured-commit/create-schema ()
  "Create the DB schema."
  (sqlite-execute
   structured-commit/db
   "CREATE TABLE IF NOT EXISTS scopes (
      project TEXT NOT NULL,
      scope   TEXT NOT NULL,
      UNIQUE(project, scope)
    )")
  structured-commit/db)

(defun structured-commit/scopes-for-project (project)
  "Return a list of scopes for PROJECT."
  (sqlite-select
   (structured-commit/database)
   "SELECT scope
    FROM scopes
    WHERE project = ?
    ORDER BY scope"
   `(,project)))

(defun structured-commit/save-scope (project scope)
  "Save a SCOPE for PROJECT."
  (sqlite-execute
   (structured-commit/database)
   "INSERT INTO scopes (project, scope)
    VALUES (?, ?)
    ON CONFLICT DO NOTHING"
   `(,project ,scope)))

(provide 'structured-commit)
