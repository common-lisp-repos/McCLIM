(in-package :climi)

;;;
;;;  Functions dealing with copying to the clipboard.
;;;

(deftype representation-type-name () '(member :string :html :image))

(defgeneric copy-to-clipboard-with-port (port sheet clipboard-p object presentation-type)
  (:documentation "Method to be implemented by backends."))

(defmethod copy-to-clipboard-with-port ((port clim:port) (sheet clim:sheet) clipboard-p object presentation-type)
  "Fallback implementation if the implementation does not support a clipboard."
  nil)

(defun copy-to-clipboard (sheet object &key presentation-type)
  "Copy OBJECT to the clipboard.
SHEET is the owner of the clipboard, and it is not guaranteed that the
content of the clipboard will be available after the sheet has been
removed."
  (copy-to-clipboard-with-port (port sheet) sheet t object presentation-type))

(defun copy-to-selection (sheet object &key presentation-type)
  "Copy OBJECT to the selection.
SHEET is the owner of the selection, and it is not guaranteed that the
content of the selection will be available after the sheet has been
removed."
  (copy-to-clipboard-with-port (port sheet) sheet nil object presentation-type))

(defgeneric clear-clipboard-with-port (port sheet clipboard-p))

(defmethod clear-clipboard-with-port (port sheet clipboard-p)
  "Fallback implementation if the implementation does not support a clipboard.."
  nil)

(defun clear-clipboard (sheet)
  (clear-clipboard-with-port (port sheet) sheet t))

(defun clear-selection (sheet)
  (clear-clipboard-with-port (port sheet) sheet nil))

(defgeneric local-selection-content (port)
  (:documentation "Returns the content of the selection in this Lisp image.
If the global selection is currently held, the value returned is the
same as what would be sent in response to a REQUEST-CLIPBOARD-CONTENT
call."))

;;;
;;;  The following functions implement the standard API to request
;;;  content from the clipboard.
;;;

(defclass clipboard-send-event (window-event)
  ((content :initarg :content
            :reader clipboard-event-content)
   (type    :initarg :type
            :reader clipboard-event-type))
  (:documentation "Event containing the result of a clipboard or selection request"))

(defgeneric request-clipboard-content-with-port (port pane clipboard-p type)
  (:documentation "Backend implementation of REQUEST-CLIPBOARD-CONTENT.")
  (:method ((port clim:port) pane clipboard-p type)
    (error "Clipboard not implemented for port: ~s" port)))

(defmethod request-clipboard-content-with-port :around (port name clipboard-p type)
  (unless (or (typep type 'climi::representation-type-name)
              (and (listp type)
                   (every (lambda (v) (typep v 'climi::representation-type-name)) type)))
    (error "Invalid type: ~s" type))
  (call-next-method))

(defun request-selection-content (pane type)
  (request-clipboard-content-with-port (port pane) pane nil type))

(defun request-clipboard-content (pane type)
  (request-clipboard-content-with-port (port pane) pane t type))