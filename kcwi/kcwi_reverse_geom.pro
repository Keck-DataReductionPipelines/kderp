;$Id: kcwi_reverse_geom.pro | Tue Mar 3 16:16:17 2015 -0800 | Don Neill  $
;
; KCWI_REVERSE_GEOM
; 
; Once the KCWI pipeline determiens the mapping, this procedure
; can be used to generate an inverse mapping that helps the user
; determine where wavelengths originally fell on the CCD.  Can serve
; as a sanity check 
;
; the procedure outputs a file:
; $OUTDIR/imageNNNNN_wavemap.fits
; where NNNNN is the cbars image number for the geometry 
;  
;
; To do:
; > change how things are loaded? 
; > add some headers to the data.

pro KCWI_REVERSE_GEOM, kgeom, ppar, degree=degree

pre = "KCWI_REVERSE_GEOM"

; Check structs
if kcwi_verify_geom(kgeom,/init) ne 0 then return
if kcwi_verify_ppar(ppar) ne 0 then begin
	ppar = {kcwi_ppar}
endif

; read in quantities from the geometry.
; trying to avoid using these inside of the code proper
  imno = kgeom.cbarsimgnum
  arcno = kgeom.arcimgnum
  nx = kgeom.nx
  ny = kgeom.ny
  ypad = kgeom.ypad
  nasmask = kgeom.nasmask
  trimy0 = kgeom.trimy0
  trimy1 = kgeom.trimy1
  kwx = kgeom.kwx
  kwy = kgeom.kwy
  xi = kgeom.xi
  yi = kgeom.yi
  xw = kgeom.xw
  yw = kgeom.yw
  slice = kgeom.slice
  refoutx = kgeom.refoutx
  x0out = kgeom.x0out
  dwout = kgeom.dwout
  wave0out = kgeom.wave0out
  ldeg = kgeom.lastdegree
  xbin = kgeom.xbinsize
  xpad = 17/xbin

; process the degree, default to 3. 
  if n_elements(degree) eq 0 then degree = ldeg
  if degree lt 2 or degree gt 4 then degree = 3 
  
  outfile = kcwi_get_imname(ppar,kgeom.cbarsimgnum,"_wavemap",/reduced)
  outfilepos = kcwi_get_imname(ppar,kgeom.cbarsimgnum,"_posmap",/reduced)
  outfilesli = kcwi_get_imname(ppar,kgeom.cbarsimgnum,"_slicemap",/reduced)
  outfiledel = kcwi_get_imname(ppar,kgeom.cbarsimgnum,"_delmap",/reduced)

  x = dindgen(nx)
  y = dindgen(ny); ypad
  onex = x-x+1.00000d
  oney = y-y+1.000000d
  
  xx = x#oney
  yy = onex#y
  
  wavemap = xx-xx-10
  delmap = wavemap
  slicemap=wavemap+100
  posmap=wavemap-90.0
  tmp_posmap=posmap
  tmp_wavemap = wavemap - wavemap
  tmp_delmap = tmp_wavemap
  ; loop over slices
  for s=0, 23 do begin
     qs = where(slice eq s and xi gt 0 and finite(xw) and finite(yw), nqs)
     if nqs eq 0 then begin
	     kcwi_print_info,ppar,pre, $
	     	"Sorry, no points in this slice. Confused. Exiting.",/error
	     return
     endif
     x0 = xi[qs]
     y0 = yi[qs]+ypad
     x1 = xw[qs]
     y1 = yw[qs]
     x0min = min(x0)
     x0temp = x0-x0min+x0out
     ; generate a mapping
     ;polywarp,x1,y1,x0temp,y0,3,kx,ky,/double
     deg2d = [2,4]
     mod_polywarp,x1,y1,x0temp,y0,deg2d,kx,ky,/double
     ; reset the "in" values
     xmm = minmax(x0)
     qin = where(xx gt xmm[0]-xpad and xx lt xmm[1]+xpad and $
     		 yy ge trimy0 and yy le trimy1, nqxin)
     if nqxin eq 0 then begin
	     kcwi_print_info,ppar,pre, $
		"Sorry, no suitable points found. Confused. Exiting.",/error
	     return
     endif
     xin = xx[qin]-x0min+x0out
     yin = yy[qin]+ypad
     kcwi_poly_map,xin,yin,kx,ky,xout,yout,deg2d=deg2d

     ; set the pixel values to the wavelengths.
     tmp_wavemap[xin-x0out+x0min,yin-ypad] = yout*dwout+wave0out
     ; delta wavelength
     tmp_delmap = tmp_wavemap - shift(tmp_wavemap,0,1)
     tmp_posmap[xin-x0out+x0min,yin-ypad] = xout ;-x0min+x0out
     qz = where(tmp_posmap ge -2/xbin and tmp_posmap le 140.0/xbin)
     slicemap[qz]=s
     posmap[qz]=tmp_posmap[qz]
     wavemap[qz] = tmp_wavemap[qz]
     delmap[qz] = tmp_delmap[qz]
     tmp_posmap[*]=-100
  endfor

  ;
  ; get header
  hdr = headfits(kgeom.cbarsfname)
  ;
  ; update header
  ;
  ; spatial scale and zero point
  sxaddpar,hdr,'BARSEP',kgeom.refdelx,' separation of bars (binned pix)'
  sxaddpar,hdr,'BAR0',kgeom.x0out,' first bar pixel position'
  ;
  ; wavelength ranges
  sxaddpar,hdr, 'WAVALL0', kgeom.waveall0, ' Low inclusive wavelength'
  sxaddpar,hdr, 'WAVALL1', kgeom.waveall1, ' High inclusive wavelength'
  sxaddpar,hdr, 'WAVGOOD0',kgeom.wavegood0, ' Low good wavelength'
  sxaddpar,hdr, 'WAVGOOD1',kgeom.wavegood1, ' High good wavelength'
  sxaddpar,hdr, 'WAVMID',kgeom.wavemid, ' middle wavelength'
  ;
  ; wavelength solution RMS
  sxaddpar,hdr,'AVWVSIG',kgeom.avewavesig,' Avg. bar wave sigma (Ang)'
  sxaddpar,hdr,'SDWVSIG',kgeom.stdevwavesig,' Stdev. bar wave sigma (Ang)'
  ;
  ; geometry solution RMS
  xmo = moment(kgeom.xrsd,/nan)
  ymo = moment(kgeom.yrsd,/nan)
  sxaddpar,hdr, 'GEOXGSG', xmo[0], ' Global geometry X sigma (pix)'
  sxaddpar,hdr, 'GEOYGSG', ymo[0], ' Global geometry Y sigma (pix)'
  ;
  ; pixel scales
  sxaddpar,hdr,'PXSCL', kgeom.pxscl*kgeom.xbinsize,' Pixel scale along slice'
  sxaddpar,hdr,'SLSCL', kgeom.slscl,' Pixel scale purpendicular to slices'
  ;
  ; geometry origins
  sxaddpar,hdr, 'CBARSNO', kgeom.cbarsimgnum,' Continuum bars image number'
  fxaddpar,hdr, 'CBARSFL', kgeom.cbarsfname,' Continuum bars image',before='CBARSNO'
  sxaddpar,hdr, 'ARCNO',   kgeom.arcimgnum, ' Arc image number'
  fxaddpar,hdr, 'ARCFL',   kgeom.arcfname, ' Arc image',before='ARCNO'
  fxaddpar,hdr, 'GEOMFL',  kgeom.geomfile,' Geometry file',after='ARCNO'

  ; write the file
  kcwi_print_info,ppar,pre,"Writing",outfilepos,/info,format='(a,1x,a)'
  mwrfits, float(posmap), outfilepos,hdr,/create
  kcwi_print_info,ppar,pre,"Writing",outfilesli,/info,format='(a,1x,a)'
  mwrfits, byte((slicemap)), outfilesli,hdr,/create
  kcwi_print_info,ppar,pre,"Writing",outfiledel,/info,format='(a,1x,a)'
  mwrfits, float(delmap), outfiledel, hdr,/create
  kcwi_print_info,ppar,pre,"Writing",outfile,/info,format='(a,1x,a)'
  mwrfits, float(wavemap), outfile, hdr,/create
  kcwi_print_info,ppar,pre,"Generated reverse maps.",/info
end
