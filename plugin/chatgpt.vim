"
" ChatGPT Vim Plugin
"

" Function to show ChatGPT responses in a new buffer (improved)
function! DisplayChatGPTResponse(response)
  if empty(a:response)
    echoerr "Error: response is empty"
    return
  endif

  let original_syntax = &syntax

  new
  setlocal buftype=nofile bufhidden=hide noswapfile nowrap nobuflisted
  setlocal modifiable
  execute 'setlocal syntax='. original_syntax

  call setline(1, split(a:response, '\n'))
  setlocal nomodifiable
  wincmd p
endfunction

function! Ask()
  let prompt = input('Ask ChatGPT: ')
  call ChatGPT(prompt)
  call DisplayChatGPTResponse(g:result)
endfunction

" ChatGPT are a set of APIs that allow you to interact with OpenAI AI.
function ChatGPT(prompt)
	let message = {
				\ 'role': "user",
				\ 'content': a:prompt
				\ }

	let messages = [message]

	let json_payload = {
				\ 'model': 'gpt-3.5-turbo',
				\ 'messages': messages,
				\ 'max_tokens': 256,
				\ 'temperature': 0.7,
				\ }
	
	let body_raw = json_encode(json_payload)
	call writefile([body_raw], '/tmp/chatgpt_body_raw.json')

	let cmd = 'curl --silent -X POST -d @/tmp/chatgpt_body_raw.json '
	let token = getenv('OPENAI_API_KEY')
	let header = "-H 'Content-Type: application/json' -H 'Authorization: Bearer " . token . "' "
	let url = 'https://api.openai.com/v1/chat/completions'

	let curl_cmd = cmd . header . url
	let raw_response = system(curl_cmd)
	let response = json_decode(raw_response)

	let g:result = response.choices[0].message.content
endfunction

function! SendHighlightedCodeToChatGPT(ask, line1, line2, context)
  " Save the current yank register
  let save_reg = @@
  let save_regtype = getregtype('@')

  " Yank the lines between line1 and line2 into the unnamed register
  execute 'normal! ' . a:line1 . 'G0v' . a:line2 . 'G$y'

  " Send the yanked text to ChatGPT
  let yanked_text = @@

  let prompt = 'Do you like my code?\n' . yanked_text

  if a:ask == 'rewrite'
    let prompt = 'I have the following code snippet, can you rewrite it more idiomatically?\n' . yanked_text
    if len(a:context) > 0
      let prompt = 'I have the following code snippet, can you rewrite to' . a:context . '?\n' . yanked_text
    endif
  elseif a:ask == 'review'
    let prompt = 'I have the following code snippet, can you provide a code review for?\n' . yanked_text
  elseif a:ask == 'explain'
    let prompt = 'I have the following code snippet, can you explain it?\n' . yanked_text
    if len(a:context) > 0
      let prompt = 'I have the following code snippet, can you explain, ' . a:context . '?\n' . yanked_text
    endif
  elseif a:ask == 'test'
    let prompt = 'I have the following code snippet, can you write a test for it?\n' . yanked_text
    if len(a:context) > 0
      let prompt = 'I have the following code snippet, can you write a test for it, ' . a:context . '?\n' . yanked_text
    endif

  endif

  call ChatGPT(prompt)

  call DisplayChatGPTResponse(g:result)
  " Restore the original yank register
  let @@ = save_reg
  call setreg('@', save_reg, save_regtype)
endfunction

function! GenerateCommitMessage()
  " get the diff of the current commit
  let diff_text = system('git diff --cached --no-untracked-files HEAD')

  let prompt = 'I have the following code changes, can you write a commit message, including a title?\n' . diff_text
  call ChatGPT(prompt)

  " Save the current buffer
  silent! write

  " Insert the response into the new buffer
  call setline(1, split(g:result, '\n'))
  setlocal modifiable

  " Go back to the original buffer
  wincmd p

  " Restore the original yank register and position
  let @@ = save_reg
  call setreg('@', save_reg, save_regtype)
  call setpos('.', save_cursor)
endfunction
"
" Commands to interact with ChatGPT
command! -nargs=0 Ask call Ask()
command! -range  -nargs=? Explain call SendHighlightedCodeToChatGPT('explain', <line1>, <line2>, <q-args>)
command! -range Review call SendHighlightedCodeToChatGPT('review', <line1>, <line2>, '')
command! -range -nargs=? Rewrite call SendHighlightedCodeToChatGPT('rewrite', <line1>, <line2>, <q-args>)
command! -range -nargs=? Test call SendHighlightedCodeToChatGPT('test', <line1>, <line2>, <q-args>)
command! GenerateCommit call GenerateCommitMessage()
