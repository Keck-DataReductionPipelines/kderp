;
; Copyright (c) 2013, California Institute of Technology. All rights
;	reserved.
;+
; NAME:
;	KCWI_GROUP_BIASES
;
; PURPOSE:
;	This procedure groups biases in the KCWI_CFG struct for a given night.
;
; CATEGORY:
;	Data reduction for the Keck Cosmic Web Imager (KCWI).
;
; CALLING SEQUENCE:
;	KCWI_GROUP_BIASES, Kcfg, Ppar, Bcfg
;
; INPUTS:
;	Kcfg	- array of struct KCWI_CFG for a given directory
;	Ppar	- KCWI_PPAR pipeline parameter struct
;
; OUTPUTS:
;	Bcfg	- a KCWI_CFG struct vector with one entry for each bias group
;
; KEYWORDS:
;
; SIDE EFFECTS:
;	Outputs pipeline parameter file in ODIR for each bias group.
;
; PROCEDURE:
;	Finds bias images by inspecting the imgtype tags in Kcfg and
;	groups contiguous bias images.  Returns a KCWI_CFG struct vector
;	with one element for each bias group which is used to associate 
;	the bias groups with other observations.
;
; EXAMPLE:
;	Group bias images from directory 'night1/' and put the resulting
;	ppar files in 'night1/redux/':
;
;	KCFG = KCWI_READ_CFGS('night1/')
;	KCWI_GROUP_BIASES, KCFG, PPAR, BCFG
;
; MODIFICATION HISTORY:
;	Written by:	Don Neill (neill@caltech.edu)
;	2013-MAY-03	Initial version
;	2013-SEP-09	Added loglun keyword
;	2013-SEP-13	Now use KCWI_PPAR struct for parameters
;	2017-JUN-29	Use first image in group as root name
;-
pro kcwi_group_biases, kcfg, ppar, bcfg
	;
	; setup
	pre = 'KCWI_GROUP_BIASES'
	ppar.nbgrps = 0
	;
	; instantiate and init a KCWI_CFG struct for the bias groups
	B = {kcwi_cfg}
	bcfg = struct_init(B)
	;
	; check inputs
	if kcwi_verify_cfg(kcfg) ne 0 then return
	if kcwi_verify_ppar(ppar) ne 0 then return
	;
	; get bias list
	biases = where(strpos(kcfg.imgtype,'bias') ge 0, nbiases)
	;
	; if we have biases, group them
	if nbiases gt 0 then begin
		;
		; set up for group counting
		maxgrps = 100
		maxmemb = 50
		groups = lonarr(maxgrps, maxmemb) - 1L
		gind = 0
		p = 0
		;
		; set up first group
		gcfg = kcfg[biases[0]]
		groups[gind,p] = biases[0]
		last = gcfg.imgnum
		p += 1
		;
		; loop over biases and gather groups
		for i=1,nbiases-1 do begin
			;
			; check binning, ccdmode, ampmode, gainmul, and sequence
			if kcfg[biases[i]].xbinsize ne gcfg.xbinsize or $
			   kcfg[biases[i]].ybinsize ne gcfg.ybinsize or $
			   kcfg[biases[i]].ccdmode ne gcfg.ccdmode or $
			   kcfg[biases[i]].gainmul ne gcfg.gainmul or $
			   (kcfg[biases[i]].imgnum - last) ne 1 or $
			   strcmp(kcfg[biases[i]].ampmode,gcfg.ampmode) ne 1 then begin
				;
			   	; new group
			   	gind += 1
				p = 0
				;
				; check for group overflow
				if gind gt maxgrps then begin
					kcwi_print_info,ppar,pre,'bias group overflow',gind,/error
					return
				endif
				;
				; first member of new group
				gcfg = kcfg[biases[i]]
				groups[gind,p] = biases[i]
				last = gcfg.imgnum
				p += 1
			endif else begin
				;
				; next member of group
				gcfg = kcfg[biases[i]]
				groups[gind,p] = biases[i]
				last = kcfg[biases[i]].imgnum
				p += 1
				;
				; check for member overflow
				if p ge maxmemb then begin
					kcwi_print_info,ppar,pre,'bias broup member overflow',p,/error
					return
				endif
			endelse
		endfor
		;
		; number of groups
		ngroups = gind + 1
		;
		; setup KCWI_CFG struct for groups
		bcfg = replicate(bcfg, ngroups)
		;
		; loop over bias groups
		g = 0	; good group counter
		for i=0,ngroups-1 do begin
			;
			; fresh copy of KCWI_PPAR struct
			pp = ppar
			;
			; get image numbers for this group
			;
			; check if skip1 set
			if ppar.biasskip1 ne 0 then $
				blist = reform(groups[i, 1:*]) $
			else	blist = reform(groups[i, *])
			good = where(blist ge 0, nmem)
			blist = blist[good]
			nims = n_elements(blist)
			;
			; do we have enough for a group?
			if nims ge pp.mingroupbias then begin
				imnums = kcfg[blist].imgnum
				rangepar,imnums,rl
				pp.biases		= rl
				bcfg[g].grouplist	= rl
				bcfg[g].nimages		= nims
				;
				; get date from first bias in series
				b = blist[0]
				bcfg[g].juliandate	= kcfg[b].juliandate
				bcfg[g].date		= kcfg[b].date
				;
				; configuration
				bcfg[g].imgtype		= 'bias'
				bcfg[g].naxis		= kcfg[b].naxis
				bcfg[g].naxis1		= kcfg[b].naxis1
				bcfg[g].naxis2		= kcfg[b].naxis2
				bcfg[g].binning		= kcfg[b].binning
				bcfg[g].xbinsize	= kcfg[b].xbinsize
				bcfg[g].ybinsize	= kcfg[b].ybinsize
				bcfg[g].ampmode		= kcfg[b].ampmode
				bcfg[g].nvidinp		= kcfg[b].nvidinp
				bcfg[g].ccdmode		= kcfg[b].ccdmode
				bcfg[g].gainmul		= kcfg[b].gainmul
				;
				; use first image in group
				gi = kcfg[b].imgnum
				grt = strmid(kcfg[b].obsfname,0, $
					     strpos(kcfg[b].obsfname,'.fit'))
				;
				; files and directories
				pp.masterbias		= grt + '_mbias.fits'
				pp.ppfname		= grt + '_mbias.ppar'
				bcfg[g].groupnum	= gi
				bcfg[g].groupfile	= pp.masterbias
				bcfg[g].grouppar	= pp.ppfname
				;
				; status
				pp.nbgrps		= 1
				pp.initialized		= 1
				pp.progid		= pre
				bcfg[g].initialized	= 1
				;
				; write out ppar file
				kcwi_write_ppar,pp
				;
				; increment group counter
				g = g + 1
			endif	; do we have enough images?
		endfor	; loop over bias groups
		;
		; all groups failed
		if g le 0 then begin
			;
			; return an uninitialized, single KCWI_CFG struct
			bcfg = bcfg[0]
			kcwi_print_info,ppar,pre,'no bias groups with >= ', $
				ppar.mingroupbias, ' images.',/warning
		;
		; some groups failed
		endif else if g lt ngroups then begin
			;
			; trim KCWI_CFG struct to only good groups
			bcfg = bcfg[0:(g-1)]
			kcwi_print_info,ppar,pre,'removing ', ngroups - g, $
				' bias groups with < ', ppar.mingroupbias, $
				' images.', format='(a,i3,a,i3,a)'
		endif	; otherwise, we are OK as is
		;
		; report number of bias groups
		ppar.nbgrps = g
		kcwi_print_info,ppar,pre,'Number of bias groups',g
	;
	; no bias frames found
	endif else $
		kcwi_print_info,ppar,pre,'no bias frames found',/warning
	;
	return
end
