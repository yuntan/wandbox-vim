scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

let s:default_compiler = {
            \ '-' : 'gcc-head',
            \ 'cpp' : 'gcc-head',
            \ 'c' : 'gcc-4.8.2-c',
            \ 'cs' : 'mcs-3.2.0',
            \ 'php' : 'php-5.5.6',
            \ 'lua' : 'lua-5.2.2',
            \ 'sql' : 'sqlite-3.8.1',
            \ 'sh' : 'bash',
            \ 'erlang' : 'erlang-maint',
            \ 'ruby' : 'ruby-2.0.0-p247',
            \ 'python' : 'python-2.7.3',
            \ 'python3' : 'python-3.3.2',
            \ 'perl' : 'perl-5.19.2',
            \ 'haskell' : 'ghc-7.6.3',
            \ 'd' : 'gdc-head',
            \ }

if exists('wandbox#default_compiler')
    for [name, compiler] in items(wandbox#default_compiler)
        let s:default_compiler[name] = compiler
    endfor
endif

let s:default_options = {
            \ '-' : '',
            \ 'cpp' : 'warning,gnu++1y,boost-1.55',
            \ 'c' : 'warning,c11',
            \ 'haskell' : 'haskell-warning',
            \ }

if exists('wandbox#default_options')
    for [name, options] in items(wandbox#default_options)
        let s:default_options[name] = type(options) == type("") ? options : join(options, ',')
        unlet options
    endfor
endif

let s:V = vital#of('wandbox-vim')
let s:OptionParser = s:V.import('OptionParser')
let s:HTTP = s:V.import('Web.HTTP')
let s:JSON = s:V.import('Web.JSON')

let s:option_parser = s:OptionParser.new()
                                   \.on('--compiler=VAL', '-c', 'Compiler command (like g++, clang, ...)')
                                   \.on('--options=VAL', '-o', 'Comma separated options (like "warning,gnu++1y"')

function! s:parse_args(args)
    " TODO: parse returned value
    let parsed = call(s:option_parser.parse, a:args, s:option_parser)
    if parsed.__unknown_args__ != []
        if parsed.__unknown_args__[0] == '--puff-puff'
            echo '三へ( へ՞ਊ ՞)へ ﾊｯﾊｯ'
            return {}
        else
            throw 'Unknown arguments: '.join(parsed.__unknown_args__, ', ')
        endif
    endif
    if has_key(parsed, 'help')
        return {}
    endif
    return parsed
endfunction

function! s:is_blank(dict, key)
    if ! has_key(a:dict, a:key)
        return 1
    endif
    return empty(a:dict[a:key])
endfunction

function! s:format_result(content)
    return printf("%s\n%s"
         \, s:is_blank(a:content, 'compiler_message') ? '' : printf("[compiler]\n%s", a:content.compiler_message)
         \, s:is_blank(a:content, 'program_message') ? '' : printf("[output]\n%s", a:content.program_message))
endfunction

function! wandbox#compile(...)
    let parsed = s:parse_args(a:000)
    if parsed == {} | return '' | endif
    let buf = substitute(join(getline(parsed.__range__[0], parsed.__range__[1]), "\n")."\n", '\\', '\\\\', 'g')
    let compiler = get(parsed, 'compiler', get(s:default_compiler, &filetype, s:default_compiler['-']))
    let options = get(parsed, 'options', get(s:default_options, &filetype, s:default_options['-']))
    let json = s:JSON.encode({'code':buf, 'options':options, 'compiler':compiler})
    let response = s:HTTP.post('http://melpon.org/wandbox/api/compile.json',
                             \ json,
                             \ {'Content-type' : 'application/json'})
    if ! response.success
        throw "Request has failed! Status " . response.status . ': ' . response.statusText
    endif
    let content = s:JSON.decode(response.content)
    return s:format_result(content)
endfunction

function! wandbox#compile_and_dump(...)
    for l in split(call('wandbox#compile', a:000), "\n")
        if l ==# '[compiler]' || l ==# '[output]'
            echohl MoreMsg
        endif
        echomsg l
        echohl None
    endfor
endfunction

function! wandbox#list()
    let response = s:HTTP.get('http://melpon.org/wandbox/api/list.json')
    if ! response.success
        throw "Request has failed! Status " . response.status . ': ' . response.statusText
    endif
    return wandbox#prettyprint#pp(s:JSON.decode(response.content))
endfunction

function! wandbox#dump_option_list()
    for l in split(wandbox#list(), "\n")
        echomsg l
    endfor
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
