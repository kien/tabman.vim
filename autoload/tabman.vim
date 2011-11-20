" =============================================================================
" Description: Tab management for Vim
" Author:      Kien Nguyen <github.com/kien>
" =============================================================================

" Static variables {{{
fu! s:opts()
	let opts = {
		\ 'g:tabman_width':    ['s:width', 25],
		\ 'g:tabman_side':     ['s:side', 'left'],
		\ 'g:tabman_specials': ['s:special', 0],
		\ }
	for [ke, va] in items(opts)
		exe 'let' va[0] '=' string(exists(ke) ? eval(ke) : va[1]) '| unl!' ke
	endfo
endf
cal s:opts()

let s:hlp =  [[
	\ '" TabMan quickhelp',
	\ '" ======================',
	\ '" <cr>,',
	\ '" e: go to tab or window',
	\ '"    under the cursor',
	\ '" ----------------------',
	\ '" x: close tab or window',
	\ '"    under the cursor',
	\ '"',
	\ '" b: delete buffer under',
	\ '"    the cursor',
	\ '" ----------------------',
	\ '" t: create a new tab',
	\ '"    with TabMan opened',
	\ '"',
	\ '" o: keep starred tab,',
	\ '"    close all others',
	\ '"',
	\ '" O: go to tab under the',
	\ '"    cursor, close all',
	\ '"    others',
	\ '" ----------------------',
	\ '" <tab>,',
	\ '" <right>:',
	\ '"    go to next tab',
	\ '"',
	\ '" <s-tab>,',
	\ '" <left>:',
	\ '"    go to previous tab',
	\ '" ----------------------',
	\ '" <down>,',
	\ '" l: move cursor to the',
	\ '"    next Tab# line',
	\ '"',
	\ '" <up>,',
	\ '" h: move cursor to the',
	\ '"    previous Tab# line',
	\ '" ----------------------',
	\ '" r: fix TabMan being',
	\ '"    the last window',
	\ '" ======================',
	\ ], ['" Press ? for help']]

let [s:maps, s:name, s:lcmap] = [{
	\ 'ManSelect()':  ['<cr>', 'e', '<2-LeftMouse>'],
	\ 'ManDelete()':  ['x'],
	\ 'ManDelete(1)': ['b'],
	\ 'ManNew()':     ['t'],
	\ 'ManOnly()':    ['o'],
	\ 'ManOnly(1)':   ['O'],
	\ 'ManJump(1)':   ['l', '<down>'],
	\ 'ManJump(-1)':  ['h', '<up>'],
	\ 'ManTab(1)':    ['<tab>', '<right>'],
	\ 'ManTab(-1)':   ['<s-tab>', '<left>'],
	\ 'ManRestore()': ['r'],
	\ 'ManHelp()':    ['?'],
	\ }, 'TabMan', 'nn <buffer> <silent>']
"}}}
" Open & Close {{{
fu! s:Open()
	let s:bnew = 1
	exe s:side == 'left' ? 'to' : 'bo' s:width.'vne' s:name
	abc <buffer>
	cal s:setupblank()
	cal s:mapkeys()
	cal s:render()
	if has('syntax') && exists('g:syntax_on')
		cal s:syntax()
	en
	unl s:bnew
	redr
	ec
endf

fu! s:Close()
	let winnr = s:bufwinnr()
	if winnr > 0
		if winnr == winnr()
			let currwin = s:side == 'left' ? winnr('#') - 1 : winnr('#')
		el
			let currwin = s:side == 'left' ? winnr() - 1 : winnr()
			exe winnr.'winc w'
		en
		try | clo! | cat | cal s:msg("Can't close last window.") | endt
		exe currwin.'winc w'
	en
endf
"}}}
" TMan Actions {{{
fu! s:ManTab(dir)
	exe a:dir > 0 ? 'tabn' : 'tabp'
endf

fu! s:ManHelp()
	let s:prvhlp = exists('s:tmhelp') ? s:tmhelp : 0
	let s:tmhelp = exists('s:tmhelp') && s:tmhelp ? 0 : 1
	cal s:render()
endf

fu! s:ManNew()
	if s:chktabnr()
		retu
	en
	let s:tnew = 1
	tabe
	cal tabman#toggle()
	unl s:tnew
endf

fu! s:ManOnly(...)
	if exists('a:1')
		cal s:ManSelect(0)
	en
	tabo
	cal s:ManUpdate(1)
endf

fu! s:ManDelete(...)
	if !has_key(s:btlines, line('.'))
		retu
	en
	let eval = s:btlines[line('.')]
	if matchstr(eval, '^\w\ze\d\+$') == 't' && !exists('a:1')
		try
			exe 'tabc' matchstr(eval, '\d\+$')
		cat
			cal s:msg("Can't close last tab.")
		endt
	elsei matchstr(eval, '\w\ze\d\+$') == 'w'
		if exists('a:1')
			exe 'bd' matchstr(eval, '\d\+\ze\w\d\+$')
		el
			let [currtab, currwin, s:snew] = [tabpagenr(), winnr(), 1]
			cal s:ManSelect()
			clo
			exe 'tabn' currtab '|' currwin.'winc w'
			unl s:snew
		en
		cal s:ManRestore()
	en
	cal s:ManUpdate(1)
endf

fu! s:ManSelect(...)
	if !has_key(s:btlines, line('.'))
		retu
	en
	let [eval, s:cview] = [s:btlines[line('.')], winsaveview()]
	exe 'tabn' matchstr(eval, '^\w\zs\d\+')
	if matchstr(eval, '\w\ze\d\+$') == 'w' && !exists('a:1')
		exe matchstr(eval, '\d\+$').'winc w'
	en
endf

fu! s:ManRestore()
	if bufname('%') !~# s:name
		retu
	en
	if winnr('$') == 1
		exe s:side == 'left' ? 'bo' : 'to' 'vne'
		winc w
	en
	exe 'vert res' s:width
endf

fu! s:ManUpdate(type)
	if s:noupdate()
		retu
	en
	if a:type == 1 && bufname('%') =~# s:name
		cal s:render()
	elsei a:type == 2
		let winnr = s:bufwinnr()
		if winnr > 0
			let currwin = winnr()
			exe winnr.'winc w'
			cal s:ManUpdate(1)
			exe currwin.'winc w'
		en
	en
endf

fu! s:ManJump(dir)
	let [lnr, tabnr] = [line('.'), s:tabnr()]
	let lim = a:dir > 0 ? tabnr[-1] : tabnr[0]
	if lnr < lim && a:dir < 0
		keepj exe tabnr[-1]
		retu
	en
	if lnr > lim && a:dir > 0
		keepj exe tabnr[0]
		retu
	en
	for nr in range(lnr + a:dir, lim, a:dir) | if s:istab(nr)
		keepj exe nr
		retu
	en | endfo
	for nr in range(a:dir > 0 ? 1 : tabnr[-1], lim, a:dir) | if s:istab(nr)
		keepj exe nr
		retu
	en | endfo
endf
"}}}
" Render {{{
fu! s:render()
	let [currtab, buftabs, &l:ma] = [tabpagenr(), s:buftabs(), 1]
	sil! %d _
	let lines = exists('s:tmhelp') && s:tmhelp ? s:hlp[0] : s:hlp[1]
	cal setline(1, lines)
	let [lnr, s:btlines, subt] = [len(lines) + 1, {}, len(s:hlp[0]) - 1]
	if exists('s:cview') && exists('s:prvhlp')
		let s:cview['lnum'] += s:prvhlp && !s:tmhelp ? - subt : subt
		unl s:prvhlp
	en
	for key in sort(keys(buftabs)[:], 's:compval')
		let [id, tlen] = [1, len(buftabs[key])]
		for val in values(buftabs[key])
			let tlen += len(val) - 2
		endfo
		cal setline(lnr, ['', 'Tab #'.(key == currtab ? key.'*' : key)])
		cal extend(s:btlines, { lnr + 1 : 't'.key })
		let lnr += 2
		for each in keys(buftabs[key]) | for winnr in buftabs[key][each][1:]
			cal setline(lnr, [(id == tlen ? '`' : '|')."-".buftabs[key][each][0]])
			cal extend(s:btlines, { lnr : 't'.key.'b'.each.'w'.winnr })
			let [lnr, id] += [1, 1]
		endfo | endfo
	endfo
	let [hlg, &l:ma] = ['%#LineNr# ', 0]
	let &l:stl = hlg.s:name.' %*%='.hlg.'Tab #'.currtab.' %*'
	if exists('s:cview')
		cal winrestview(s:cview)
	en
endf
"}}}
" Utilities {{{
fu! s:buftabs()
	let buftabs = {}
	for nr in range(1, tabpagenr('$'))
		let bufs = s:validbufs(tabpagebuflist(nr))
		cal map(keys(bufs), 'extend(bufs[v:val], s:dupwin(nr, v:val))')
		cal extend(buftabs, { nr : bufs })
	endfo
	retu buftabs
endf

fu! s:validbufs(bufs)
	let bufs = {}
	for each in a:bufs
		let bufname = empty(bufname(each)) ? '<no name>'
			\ : getbufvar(each, '&bt') == 'quickfix' ? 'quickfix' : bufname(each)
		if (getbufvar(each, '&bl') && !empty(bufname(each))
			\ && empty(getbufvar(each, '&bt')) && getbufvar(each, '&ma')) || s:special
			let mod = getbufvar(each, '&mod') ? '+' : ''
			cal extend(bufs, { each : [fnamemodify(bufname, ':t').mod] })
		en
	endfo
	retu bufs
endf

fu! s:dupwin(t, buf)
	let [currtab, s:dnew] = [tabpagenr(), 1]
	exe 'tabn' a:t
	let winnrs = filter(range(1, winnr('$')), 'winbufnr(v:val) == a:buf')
	exe 'tabn' currtab
	unl s:dnew
	retu winnrs
endf

fu! s:tabnr()
	retu sort(filter(range(1, max(keys(s:btlines))), 's:istab(v:val)'), 's:compval')
endf

fu! s:chktabnr()
	retu tabpagenr('$') >= 30 && !(has('win32') || has('win64')) && !empty(&tal)
endf

fu! s:istab(t)
	retu has_key(s:btlines, a:t) && matchstr(s:btlines[a:t], '^\w\ze\d\+$') == 't'
endf

fu! s:noupdate()
	retu exists('s:tnew') || exists('s:snew') || exists('s:bnew') || exists('s:dnew')
endf

fu! s:mapkeys()
	for [ke, va] in items(s:maps) | for kp in va
		exe s:lcmap kp ':<c-u>cal <SID>'.ke.'<cr>'
	endfo | endfo
	exe s:lcmap '<c-^> <Nop>'
endf

fu! s:compval(...)
	retu a:1 - a:2
endf

fu! s:setupblank()
	setl noswf nobl nonu nowrap nolist nospell nocuc nocul wfw
	setl fdc=0 fdl=99 tw=0 bt=nofile bh=unload
	if v:version >= 703
		setl nornu noudf cc=0
	en
endf

fu! s:msg(msg)
	redr
	echoh Identifier
	echon s:name.": ".a:msg
	echoh None
endf

fu! s:syntax()
	sy match TabManTName '^Tab #\d\+$\|^".*\zsTab#'
	sy match TabManCurTName '^Tab #\d\+\ze\*$'
	sy match TabManAtv '\*$'
	sy match TabManLead '[|`]-'
	sy match TabManTag '+$'
	sy match TabManHKey '" \zs[^ ]*\ze[:,]'
	sy match TabManHelp '^".*' contains=TabManHKey,TabManTName
	hi def link TabManTName Directory
	hi def link TabManCurTName Identifier
	hi def link TabManAtv Title
	hi def link TabManLead Special
	hi def link TabManTag Title
	hi def link TabManHKey Identifier
	hi def link TabManHelp String
endf

fu! s:bufwinnr()
	let tbm = filter(range(1, winnr('$')), 'bufname(winbufnr(v:val)) == s:name')
	retu empty(tbm) ? 0 : tbm[0]
endf
"}}}
" Public {{{
fu! tabman#focus()
	let winnr = s:bufwinnr()
	if winnr > 0
		exe winnr.'winc w'
	el
		cal s:Open()
	en
endf

fu! tabman#toggle()
	cal call(s:bufwinnr() ? 's:Close' : 's:Open', [])
endf

if has('autocmd')
	au BufEnter TabMan cal s:ManUpdate(1)
	au CursorMoved TabMan let s:cview = winsaveview()
	au TabEnter,CursorHold * cal s:ManUpdate(2)
en
"}}}

" vim:fen:fdl=0:fdc=1:ts=2:sw=2:sts=2
