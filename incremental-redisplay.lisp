;;; -*- Mode: Lisp; Package: CLIM-INTERNALS -*-

;;;  (c) copyright 2002 by Michael McDonald (mikemac@mikemac.com)
;;;  (c) copyright 2002 by Tim Moore (moore@bricoworks.com)

;;; This library is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU Library General Public
;;; License as published by the Free Software Foundation; either
;;; version 2 of the License, or (at your option) any later version.
;;;
;;; This library is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; Library General Public License for more details.
;;;
;;; You should have received a copy of the GNU Library General Public
;;; License along with this library; if not, write to the 
;;; Free Software Foundation, Inc., 59 Temple Place - Suite 330, 
;;; Boston, MA  02111-1307  USA.

(in-package :CLIM-INTERNALS)

(defclass updating-output-record (output-record)
  ())

(defclass updating-output-record-mixin (compound-output-record
					updating-output-record)
  ((unique-id :reader output-record-unique-id :initarg :unique-id)
   (id-test :reader output-record-id-test :initarg :id-test
	    :initform #'eql)
   (cache-value :reader output-record-cache-value :initarg :cache-value)
   (cache-test :reader output-record-cache-test :initarg :cache-test
	       :initform #'eql)
   (fixed-position :reader output-record-fixed-position
		   :initarg :fixed-position :initform nil)
   (displayer :reader output-record-displayer :initarg :displayer)
   (sub-record :accessor sub-record
	       :documentation "The actual contents of this record.  All output
record operations are forwarded to this record.")
   ;; Start and end cursor
   (start-x :accessor start-x)
   (start-y :accessor start-y)
   (end-x :accessor end-x)
   (end-y :accessor end-y)
   ;; Old record position
   (old-x :accessor old-x)
   (old-y :accessor old-y)
   (old-start-x :accessor old-start-x)
   (old-start-y :accessor old-start-y)
   ;; XXX Need to capture the "user" transformation, I think; deal with that
   ;; later.
   (old-subrecord :accessor old-children
		 :documentation "Contains the output record tree for the
  current display.")
   (id-map :accessor id-map :initform nil)))

(defmethod initialize-instance :after ((obj updating-output-record-mixin)
				       &key)
  (multiple-value-bind (x y)
      (output-record-position obj)
    (setf (sub-record obj) (make-instance 'standard-sequence-output-record
					  :x-position x :y-position y
					  :parent obj))))

(defmethod output-record-children ((record updating-output-record-mixin))
  (list (sub-record record)))

(defmethod output-record-count ((record updating-output-record-mixin))
  1)

(defmethod map-over-output-records
    (function (record updating-output-record-mixin)
     &optional (x-offset 0) (y-offset 0)
     &rest function-args)
  (declare (ignore x-offset y-offset))
  (apply function (sub-record record) function-args)
  nil)

(defmethod map-over-output-records-containing-position
    (function (record updating-output-record-mixin) x y
     &optional (x-offset 0) (y-offset 0)
     &rest function-args)
  (declare (ignore x-offset y-offset))
  (let ((child (sub-record record)))
    (when (and (multiple-value-bind (min-x min-y max-x max-y)
		   (output-record-hit-detection-rectangle* child)
		 (and (<= min-x x max-x) (<= min-y y max-y)))
	       (output-record-refined-position-test child x y))
      (apply function child function-args))
    nil))

(defmethod map-over-output-records-overlapping-region
    (function (record updating-output-record-mixin) region
     &optional (x-offset 0) (y-offset 0)
     &rest function-args)
  (declare (ignore x-offset y-offset))
  (let ((child (sub-record record)))
    (when (region-intersects-region-p region child)
      (apply function child function-args))
    nil))

(defmethod add-output-record (child (record updating-output-record-mixin))
  (add-output-record child (sub-record record)))

(defmethod delete-output-record (child (record updating-output-record-mixin)
				 &optional (errorp t))
  (delete-output-record child (sub-record record) errorp))

(defmethod clear-output-record ((record updating-output-record-mixin))
  (clear-output-record (sub-record record)))

(defclass standard-updating-output-record (updating-output-record-mixin)
  ())

(defclass updating-output-stream-mixin ()
  ((redisplaying-p :reader stream-redisplaying-p :initform nil)
   (id-map :accessor id-map :initform nil)))

(defvar *current-updating-output* nil)

;;; Work in progress
#+nil
(defmethod invoke-updating-output ((stream updating-output-stream-mixin)
				   continuation
				   (record-type
				    (eql 'standard-updating-output-record))
				   unique-id id-test cache-value cache-test
				   &key (fixed-position nil) (all-new nil)
				   (parent-cache nil))
  (with-accessors ((id-map id-map))
      (cond (parent-cache
	     (id-map parent-cache))
	    (*current-updating-output*
	     (id-map *current-updating-output*))
	    (t (id-map stream)))
    (let ((record (find unique-id id-map :test id-test)))
      (cond ((or all-new (not (stream-redisplaying-p)))
	     (setf id-map (delete record id-map :test #'eq))
	     (with-output-to-output-record (stream record-type
					    *current-updating-output*
					    :unique-id unique-id
					    :id-test id-test
					    :cache-value cache-value
					    :cache-test cache-test
					    :fixed-position fixed-position
					    :displayer continuation)
	       (push *current-updating-output* id-map)
	       (funcall continuation stream)
	       *current-updating-output*))
	    ((null record)
	     (error "No output record for updating output!"))
	    ((not (funcall cache-test
			   cache-value
			   (output-record-cache-value record)))
	     (compute-new-output-records-1 record stream continuation)
	     record)
	    (t (maybe-move-output-record record stream)
	       record)))))


(defmethod invoke-updating-output (stream
				   continuation
				   (record-type
				    (eql 'standard-updating-output-record))
				   unique-id id-test cache-value cache-test
				   &key (fixed-position nil) (all-new nil)
				   (parent-cache nil))
  (funcall continuation stream))

(defmacro updating-output
    ((stream &rest args
      &key (unique-id (gensym)) (id-test '#'eql) cache-value (cache-test '#'eql)
      (fixed-position nil fixed-position-p)
      (all-new nil all-new-p)
      (parent-cache nil parent-cache-p)
      (record-type ''standard-updating-output-record))
     &body body)
  (declare (ignore fixed-position))
  (when (eq stream t)
    (setq stream '*standard-output*))
  (let ((func (gensym "UPDATING-OUTPUT-CONTINUATION")))
    `(flet ((,func (,stream)
	      ,@body))
       (invoke-updating-output ,stream #',func ,record-type ,unique-id
			       ,id-test ,cache-value ,cache-test
	                       ,@ (and fixed-position-p
				       `(:fixed-position ,fixed-position))
			       ,@(and all-new-p `(:all-new ,all-new))
			       ,@(and parent-cache-p
				      `(:parent-cache ,parent-cache))))))
