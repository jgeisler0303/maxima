;;; -*-  Mode: Lisp; Package: Maxima; Syntax: Common-Lisp; Base: 10 -*- ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;     The data in this file contains enhancments.                    ;;;;;
;;;                                                                    ;;;;;
;;;  Copyright (c) 1984,1987 by William Schelter,University of Texas   ;;;;;
;;;     All rights reserved                                            ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :maxima)

;;	** (c) Copyright 1982 Massachusetts Institute of Technology **

(macsyma-module dskfn)

(declare-top (special opers $packagefile
		      fasdumpfl fasdeqlist fasdnoneqlist savenohack
		      aaaaa errset lessorder greatorder indlist
		      $labels $aliases varlist *mopl* $props defaultf
		      $infolists $features featurel savefile $gradefs
		      $values $functions $arrays
		      $contexts context $activecontexts))

(setq $packagefile nil
      indlist '(evfun evflag bindtest nonarray sp2 sp2subs opers
		 special autoload assign mode))

(defun infolstchk (x)
  (let ((iteml (cond ((not (and x (or (member (car x) '($all $contexts) :test #'eq)
				      (member (car x) (cdr $infolists) :test #'eq))))
		      t)
		     ((eq (car x) '$all)
		      (infolstchk (append (cdr $infolists)
					  '($linenum $ratvars $weightlevels *ratweights
					    tellratlist *alphabet* $dontfactor $features $contexts))))
		     ((eq (car x) '$labels) (reverse (cdr $labels)))
		     ((member (car x) '($functions $macros $gradefs $dependencies) :test #'eq)
		      (mapcar #'caar (cdr (symbol-value (car x)))))
		     ((eq (car x) '$contexts) (delete '$global (reverse (cdr $contexts)) :count 1 :test #'eq))
		     (t (cdr (symbol-value (car x)))))))
    (if (eq iteml t)
	x
	(append (or iteml '(nil)) (cdr x)))))

(defmspec $save (form)
  (let ((*print-circle* nil) (*print-level* nil) (*print-length* nil) (*print-base* 10.) (*print-radix* t)) ; $save stores Lisp expressions.
    (dsksetup (cdr form) nil nil '$save)))

(defvar *macsyma-extend-types-saved* nil)

(defun dsksetup (x storefl fasdumpfl fn)
  (let (file (fname (meval (car x)))
		   *print-gensym* list fasdeqlist fasdnoneqlist maxima-error)
    (unless (stringp fname)
      (merror (intl:gettext "~a: first argument must be a string; found: ~M") fn fname))
    (setq savefile
	  (if (or (eq $file_output_append '$true) (eq $file_output_append t))
	      (open fname :direction :output :if-exists :append :if-does-not-exist :create)
	      (open fname :direction :output :if-exists :supersede :if-does-not-exist :create)))
    (setq file (list (car x)))
    (when (null fasdumpfl)
      (princ ";;; -*- Mode: LISP; package:maxima; syntax:common-lisp; -*- " savefile)
      (terpri savefile)
      (princ "(in-package :maxima)" savefile))
    ;; Check arguments. First argument was checked above.
    ;; May want to relax requirement that all atoms be symbols.
    (dolist (u (cdr x))
      (cond ((atom u) (if (not (symbolp u)) (improper-arg-err u fn)))
	    ((listargp u))
	    ((or (not (eq (caar u) 'mequal)) (not (symbolp (cadr u))))
	     (improper-arg-err u fn))))
    (setq list (ncons (car x))
	  x (cdr x)
	  *macsyma-extend-types-saved* nil)
    (if (null (errset (dskstore x storefl file list)))
	(setq maxima-error t))
    ;; FOLLOWING CODE IS NEVER EXECUTED DUE TO PRECEDING (SETQ *MACSYMA-EXTEND-TYPES-SAVED* NIL)
    ;; CUT (DEFVAR *MACSYMA-EXTEND-TYPES-SAVED*) AND FOLLOWING CODE AT SOME FUTURE DATE
    (if (not (null *macsyma-extend-types-saved*))
	(block nil
	  (if (null (errset
		     (dskstore (cons "{" *macsyma-extend-types-saved*) storefl file list)))
	      (setq maxima-error t))
	  (setq *macsyma-extend-types-saved* nil)))
    (close savefile)
    (namestring (truename savefile))))

(defun dskstore (x storefl file list)
  (do ((x x (cdr x))
       (val)
       (rename)
       (item)
       (alrdystrd)
       (stfl storefl storefl)
       (nitemfl nil nil))
      ((null x))
    (cond ((setq val (listargp (car x)))
	   (setq x (nconc (getlabels (car val) (cdr val) nil) (cdr x))))
	  ((setq val (assoc (car x) '(($inlabels . $inchar) ($outlabels . $outchar)
				     ($linelabels . $linechar)) :test #'eq))
	   (setq x (nconc (getlabels* (eval (cdr val)) nil) (cdr x)))))
    (if (not (atom (car x)))
	(setq rename (cadar x) item (getopr (caddar x)))
	(setq x (infolstchk x) item (setq rename (and x (getopr (car x))))))
    (cond ((not (symbolp item))
	   (setq nitemfl item)
	   (setq item (let ((nitem (gensym))) (set nitem (meval item)) nitem)))
	  ((eq item '$ratweights) (setq item '*ratweights))
	  ((eq item '$tellrats) (setq item 'tellratlist))
      ((eq item '$alphabet) (setq item '*alphabet*)))
    (cond
      ((null x) (return nil))
      ((null (car x)))
      ((and (setq val (assoc item alrdystrd :test #'eq)) (eq rename (cdr val))))
      ((null (setq alrdystrd (cons (cons item rename) alrdystrd))))
      ((and (or (not (boundp item))
		(and (eq item '$ratvars) (null varlist))
		(prog2 (setq val (symbol-value item))
		    (or (and (member item '($weightlevels $dontfactor) :test #'eq)
			     (null (cdr val)))
			(and (member item '(tellratlist *alphabet* *ratweights) :test #'eq) (null val))
			(and (eq item '$features) (alike (cdr val) featurel))
			(and (eq item '$default_let_rule_package)
                             (eq item val)))))
            (or ;; This clause has been reformulated to cut out a test with
                ;; dsksavep and unstorep, but to respect the side effects.
                (null (setq val (safe-get item 'mprops)))
                (equal val '(nil))
                nil)
	    (not (getl item '(operators reversealias grad noun verb expr op data)))
	    (not (member item (cdr $props) :test #'eq))
	    (or (not (member item (cdr $contexts) :test #'eq))
		(not (eq item '$initial))
		(let ((context '$initial)) (null (cdr ($facts '$initial)))))))
      (t (when (boundp item)
           (setq val (symbol-value item))
	   (if (eq item '$context) (setq x (list* nil val (cdr x))))
	   (dskatom item rename val)
	   (if (not (optionp rename)) (infostore item file 'value stfl rename)))
	 (when (setq val (and (member item (cdr $aliases) :test #'eq) (get item 'reversealias)))
	   (dskdefprop rename val 'reversealias)
	   (pradd2lnc rename '$aliases)
	   (dskdefprop val rename 'alias)
	   (and greatorder (not (assoc 'greatorder alrdystrd :test #'eq))
		(setq x (list* nil 'greatorder (cdr x))))
	   (and lessorder (not (assoc 'lessorder alrdystrd :test #'eq))
		(setq x (list* nil 'lessorder (cdr x))))
	   (setq x (list* nil val (cdr x))))
	 (cond ((setq val (get item 'noun))
		(setq x (list* nil val (cdr x)))
		(dskdefprop rename val 'noun))
	       ((setq val (get item 'verb))
		(setq x (list* nil val (cdr x)))
		(dskdefprop rename val 'verb)))
	 (when (mget item '$rule)
	   (if (setq val (ruleof item))
	       (setq x (list* nil val (cdr x))))
	   (pradd2lnc (getop rename) '$rules))
	 (when (and (setq val (cadr (getl-lm-fcn-prop item '(expr))))
		    (or (mget item '$rule) (get item 'translated)))
	   (if (mget item 'trace)
	       (let (val1)
		 (remprop item 'expr)
		 (if (setq val1 (get item 'expr))
		     (dskdefprop rename val1 'expr))
		 (setf (symbol-plist item) (list* 'expr val (symbol-plist item))))
	       (dskdefprop rename val 'expr))
	   (propschk item rename 'translated))
	 (when (setq val (get item 'operators))
	   (dskdefprop rename val 'operators)
	   (when (setq val (get item 'rules))
	     (dskdefprop rename val 'rules)
	     (setq x (cons nil (append val (cdr x)))))
	   (if (member item (cdr $props) :test #'eq) (pradd2lnc rename '$props))
	   (setq val (mget item 'oldrules))
	   (and val (setq x (cons nil (nconc (cdr (reverse val)) (cdr x))))))
	 (if (member item (cdr $features) :test #'eq) (pradd2lnc rename '$features))
	 (when (member (getop item) (cdr $props) :test #'eq)
	   (dolist (ind indlist) (propschk item rename ind))
	   (dolist (oper opers) (propschk item rename oper)))
	 (when (and (setq val (get item 'op)) (member val (cdr $props) :test #'eq))
	   (dskdefprop item val 'op)
	   (dskdefprop val item 'opr)
	   (pradd2lnc val '$props)
	   (if (setq val (extopchk item val))
	       (setq x (list* nil val (cdr x)))))
	 (when (and (setq val (get item 'grad)) (assoc (ncons item) $gradefs :test #'equal))
	   (dskdefprop rename val 'grad)
	   (pradd2lnc (cons (ncons rename) (car val)) '$gradefs))
	 (when (and (get item 'data)
		    (not (member item (cdr $contexts) :test #'eq))
		    (setq val (cdr ($facts item))))
	   (fasprin `(restore-facts (quote ,val)))
	   (if (member item (cdr $props) :test #'eq) (pradd2lnc item '$props)))
	 (when (and (member item (cdr $contexts) :test #'eq)
		    (let ((context item)) (setq val (cdr ($facts item)))))
	   (fasprint t `(dsksetq $context (quote ,item)))
	   (if (member item (cdr $activecontexts) :test #'eq)
	       (fasprint t `($activate (quote ,item))))
	   (fasprint t `(restore-facts (quote ,val))))
	 (mpropschk item rename file stfl)
	 (if (not (get item 'verb))
	     (nconc list (ncons (or nitemfl (getop item)))))))))

(defun dskatom (item rename val)
  (cond ((eq item '$ratvars)
	 (fasprint t `(setq varlist (append varlist (quote ,varlist))))
	 (fasprint t '(setq $ratvars (cons '(mlist simp) varlist)))
	 (pradd2lnc '$ratvars '$myoptions))
	((member item '($weightlevels $dontfactor) :test #'eq)
	 (fasprin `(setq ,item (nconc (quote ,val) (cdr ,item))))
	 (pradd2lnc item '$myoptions))
	((eq item 'tellratlist)
	 (fasprin `(setq tellratlist (nconc (quote ,val) tellratlist)))
	 (pradd2lnc 'tellratlist '$myoptions))
    ((eq item '*alphabet*)
     (fasprin `(setq *alphabet* (nconc (quote ,val) *alphabet*))))
	((eq item '*ratweights)
	 (fasprin `(apply (function $ratweight) (quote ,(dot2l val)))))
	((eq item '$features)
	 (dolist (var (cdr $features))
	   (if (not (member var featurel :test #'eq)) (pradd2lnc var '$features))))
	((and (eq item '$linenum) (eq item rename))
	 (fasprint t `(setq $linenum ,val)))
	((not ($ratp val))
	 (fasprint t (list 'dsksetq rename
			   (if (or (numberp val) (member val '(nil t) :test #'eq))
			       val
			       (list 'quote val)))))
	(t (fasprint t `(dsksetq ,rename (dskrat (quote ,val)))))))

(defun mpropschk (item rename file stfl)
  (do ((props (cdr (or (get item 'mprops) '(nil))) (cddr props)) (val))
      ((null props))
    (cond ((or (member (car props) '(trace trace-type trace-level trace-oldfun) :test #'eq)
               ;; This clause has been reformulated to cut out a mfile-test,
               ;; but to respect the side effect of assigning a value to val.
               (and (setq val (cadr props)) nil)
               (and (eq (car props) 't-mfexpr)
                    (not (get item 'translated)))))
	  ((not (member (car props) '(hashar array) :test #'eq))
	   (fasprin (list 'mdefprop rename val (car props)))
	   (if (not (member (car props) '(mlexprp mfexprp t-mfexpr) :test #'eq))
	       (infostore item file (car props) stfl
			  (cond ((member (car props) '(mexpr mmacro) :test #'eq)
				 (let ((val1 (get item 'function-mode)))
				   (if val1 (dskdefprop rename
							val1
							'function-mode)))
				 (cons (ncons rename) (cdadr val)))
				((eq (car props) 'depends)
				 (cons (ncons rename) val))
				(t rename)))))
	  (t (dskary item (list 'quote rename) val (car props))
	     (infostore item file (car props) stfl rename)))))

(defun dskary (item rename val ind)
  ;; Some small forms ordinarily non-EQ for fasdump must be output
  ;; in proper sequence with the big mungeables.
  ;; For this reason only they are output as EQ-forms.
  (let ((ary (cond ((and (eq ind 'array) (get item 'array)) rename)
		   ;; This code handles "complete" arrays.
		   (t (fasprint t '(setq aaaaa (gensym))) 'aaaaa)))
	(dims (arraydims val))
	val1)
    (if (eq ind 'hashar) (fasprint t `(remcompary ,rename)))
    (fasprint t `(mremprop ,rename (quote ,(if (eq ind 'array) 'hashar 'array))))
    (fasprint t `(mputprop ,rename ,ary (quote ,ind)))
    (fasprint t `(*array ,ary (quote ,(car dims)) ,.(cdr dims)))
    (fasprint t `(fillarray ,ary (quote ,(listarray val))))
    (if (setq val1 (get item 'array-mode))
	(fasprint t `(defprop ,(cadr rename) ,val1 array-mode)))))

(defun extopchk (item val)
  (let ((val1 (implode (cons #\$ (cdr (exploden val))))))
    (when (or (get val1 'nud) (get val1 'led) (get val1 'lbp))
      (fasprin `(define-symbol (quote ,val)))
      (if (member val *mopl* :test #'eq)
	  (fasprin `(setq *mopl* (cons (quote ,val) *mopl*))))
      (when (setq val (get val1 'dimension))
	(dskdefprop val1 val 'dimension)
	(dskdefprop val1 (get val1 'dissym) 'dissym)
	(dskdefprop val1 (get val1 'grind) 'grind))
      (if (setq val (get val1 'lbp)) (dskdefprop val1 val 'lbp))
      (if (setq val (get val1 'rbp)) (dskdefprop val1 val 'rbp))
      (if (setq val (get val1 'nud)) (dskdefprop val1 val 'nud))
      (if (setq val (get val1 'led)) (dskdefprop val1 val 'led))
      (when (setq val (get val1 'verb))
	(dskdefprop val (get val 'dimension) 'dimension)
	(dskdefprop val (get val 'dissym) 'dissym))
      (when (setq val (get item 'match))
	(dskdefprop item val 'match) val))))

(defun propschk (item rename ind)
  (let ((val (get item ind)))
    (when val (dskdefprop rename val ind)
	  (pradd2lnc (getop rename) '$props))))

(defun fasprin (form)
  (fasprint nil form))

(defun fasprint (eqfl form)
  (cond ((null fasdumpfl) (print form savefile))
	(eqfl (setq fasdeqlist (cons form fasdeqlist)))
	(t (setq fasdnoneqlist (cons form fasdnoneqlist)))))

(defun infostore (item file flag storefl rename)
  (let ((prop (cond ((eq flag 'value)
		     (if (member rename (cdr $labels) :test #'eq) '$labels '$values))
		    ((eq flag 'mexpr) '$functions)
		    ((eq flag 'mmacro) '$macros)
		    ((member flag '(array hashar) :test #'eq) '$arrays)
		    ((eq flag 'depends) (setq storefl nil) '$dependencies)
		    (t (setq storefl nil) '$props))))
    (cond ((eq prop '$labels)
	   (fasprin `(addlabel (quote ,rename)))
	   (if (get item 'nodisp) (dskdefprop rename t 'nodisp)))
	  (t (pradd2lnc rename prop)))
    (cond (storefl
	   (cond ((member flag '(mexpr mmacro) :test #'eq) (setq rename (caar rename)))
		 ((eq flag 'array) (remcompary item)))
	   (setq prop (list '(mfile) file rename))
	   (cond ((eq flag 'value) (set item prop))
		 ((member flag '(mexpr mmacro aexpr array hashar) :test #'eq)
		  (mputprop item prop flag)))))))

(defun pradd2lnc (item prop)
  (if (or (null $packagefile) (not (member prop (cdr $infolists) :test #'eq))
	  (and (eq prop '$props) (getopr0 item)))
      (fasprin `(add2lnc (quote ,item) ,prop))))

(defun dskdefprop (name val ind)
  (declare (special *opr-table*))
  (fasprin
    (cond
      ((and (member ind '(expr fexpr macro) :test #'eq) (eq (car val) 'lambda))
       (list* 'defun name (if (eq ind 'expr) (cdr val) (cons ind (cdr val)))))
      ((eq ind 'opr)
       (if (symbolp name)
         (list 'defprop name val ind)
         `(setf (gethash ,name *opr-table*) ',val)))
      (t
        (list 'defprop name val ind)))))

