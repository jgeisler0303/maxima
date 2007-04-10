;;; -*-  Mode: Lisp; Package: Maxima; Syntax: Common-Lisp; Base: 10 -*- ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;     The data in this file contains enhancments.                    ;;;;;
;;;                                                                    ;;;;;
;;;  Copyright (c) 1984,1987 by William Schelter,University of Texas   ;;;;;
;;;     All rights reserved                                            ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;     (c) Copyright 1981 Massachusetts Institute of Technology         ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :maxima)

;;; Interpolation routine by CFFK.

(macsyma-module intpol)

(load-macsyma-macros transm numerm)

(declare-top (special $find_root_rel $find_root_abs $find_root_error)) 

(or (boundp '$find_root_abs) (setq $find_root_abs 0d0)) 
(or (boundp '$find_root_rel) (setq $find_root_rel 0d0))
(or (boundp '$find_root_error) (setq $find_root_error t))

(defmspec $interpolate (form)
  (format t "NOTE: The interpolate function has been renamed to find_root.
The variables intpolabs, intpolrel, and intpolerror have been renamed
to find_root_abs, find_root_rel, and find_root_error, respectively.
Perhaps you meant to enter `~a'.~%"
	  (print-invert-case (implode (mstring `(($find_root) ,@(cdr form))))))
  '$done)

(defun $find_root_subr (f left right)
  (bind-tramp1$
   f f
   (prog (a b c fa fb fc (lin 0))
      (declare (fixnum lin))
      (setq a (float left)
	    b (float right))
      (or (> b a) (setq a (prog1 b (setq b a))))
      (setq fa (funcall f a)
	    fb (funcall f b))
      (or (> (abs fa) $find_root_abs) (return a))
      (or (> (abs fb) $find_root_abs) (return b))
      (and (plusp (* fa fb))
	   (cond ((eq $find_root_error t)
		  (merror "function has same sign at endpoints~%~M"
			  `((mlist)
			    ((mequal) ((f) ,a) ,fa)
			    ((mequal) ((f) ,b) ,fb))))
		 (t (return $find_root_error))))
      (and (> fa 0d0)
	   (setq fa (prog2 nil fb (setq fb fa)) a (prog2 nil b (setq b a))))
      (setq lin 0)
      binary
      (setq c (* (+ a b) 0.5d0)
	    fc (funcall f c))
      (and (interpolate-check a c b fc) (return c))
      (cond ((< (abs (- fc (* (+ fa fb) 0.5d0))) (* 1d-1 (- fb fa)))
	     (incf lin))
	    (t (setq lin 0)))
      (cond ((> fc 0d0) (setq fb fc b c)) (t (setq fa fc a c)))
      (or (= lin 3) (go binary))
      falsi
      (setq c (cond ((plusp (+ fb fa))
		     (+ a (* (- b a) (/ fa (- fa fb)))))
		    (t (+ b (* (- a b) (/ fb (- fb fa)))))) 
	    fc (funcall f c))
      (and (interpolate-check a c b fc) (return c))
      (cond ((plusp fc) (setq fb fc b c)) (t (setq fa fc a c)))
      (go falsi))))

(defun interpolate-check (a c b fc)
  (not (and (prog1 (> (abs fc) $find_root_abs) (setq fc (max (abs a) (abs b))))
	    (> (abs (- b c)) (* $find_root_rel fc))
	    (> (abs (- c a)) (* $find_root_rel fc)))))

(defun interpolate-macro (form translp)
  (setq form (cdr form))
  (cond ((= (length form) 3)
	 (cond (translp
		`(($find_root_subr) ,@form))
	       (t
		`((mprog) ((mlist) ((msetq) $numer t) ((msetq) $%enumer t))
		  (($find_root_subr) ,@form)))))
	((= (length form) 4)
	 (destructuring-let (((exp var . bnds) form))
	   (setq exp (sub ($lhs exp) ($rhs exp)))
	   (cond (translp
		  `(($find_root_subr)
		    ((lambda-i) ((mlist) ,var)
		     (($modedeclare) ,var $float)
		     ,exp)
		    ,@bnds))
		 (t
		  `((mprog) ((mlist) ((msetq) $numer t) ((msetq) $%enumer t))
		    (($find_root_subr)
		     ((lambda) ((mlist) ,var) ,exp)
		     ,@bnds))))))
	(t (merror "wrong number of args to `interpolate'"))))

(defmspec $find_root (form)
  (meval (interpolate-macro form nil)))

(def-translate-property $find_root (form)
  (let (($tr_numer t))
    (translate (interpolate-macro form t))))
