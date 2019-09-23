# Jacob McBlane <jacobmcblane@gmail.com>
# silentmessengers.org
# Version: 0.0.91
#
# Customize the variables on lines ~30 to fit your needs.
#
# Report any bugs or comments to me, please!
# Note: There are surely bugs!
#
# Launch the app and type help for instructions.
#
# TODO: - Add more safety!
#       - Check for uri type when loading initial uri. (Partially in)
#       - Dynamic ports? See proc dl_uri
#       - Remove $PAGER dependency for pure Nim.

from os import getHomeDir, dirExists, createDir, fileExists, paramStr, execShellCmd, removeDir, paramCount
from net import newSocket, connect, Port, send, recvLine, recv
from browsers import openDefaultBrowser
from terminal import terminalHeight, getch
from parseutils import parseInt
from sequtils import delete
from strutils import strip, join, split, splitLines, parseInt
from md5 import getMD5
from re import findAll, re, match, replace

let
  home = "silentmessengers.org"
  tmpdir = "/tmp/nimph/"
  bookmarks = getHomeDir() & ".config/nimphmarks"

 # Fancy characters
  www = " 爵 "
  txt = "   "
  dir = "   "
  err = "   "
  fts = "   "
  tel = "   "
  bin = "   "
  img = "   "

  # Some plain character suggestions
#  www = " @ "
#  txt = " # "
#  dir = " / "
#  err = " ! "
#  fts = " ? "
#  tel = " > "
#  bin = " $ "
#  img = " % "

type Line = tuple[
  kind: string,
  text: string,
  path: string,
  domain: string,
  port: string ]

type Hole = seq[Line]

let errorpage: Hole =
  @[("", "", "", "", ""),
    ("i", "", "", "Err", ""),
    ("i", "", "", "Err", ""),
    ("i", "Error:", "", "Err", ""),
    ("i", "------", "", "Err", ""),
    ("i", "", "", "Err", ""),
    ("i", "Couldn't navigate to page.", "", "Err", ""),
    ("i", "", "", "Err", ""),
    ("i", "Looks like the request timed out or something.", "", "Err", ""),
    ("i", "", "", "Err", ""),
    ("1", "    Visit " & home, "/", home, "70"),
    ("7", "    Search w/ Veronica II", "/v2/vs", "gopher.floodgap.com", "70"),
    ("i", "", "", "Err", ""),
    ("i", "", "", "Err", "")]

var
 tour = newSeq[string]()
 nav = newSeq[string]()
 history = newSeq[string]()
 auto_page = false

if dirExists(tmpdir) == false:
  createDir(tmpdir)

proc re_wrap(s: string): string =
  if s.len() < 70: result = s
  else:
    var ss: seq[string]
    for m in s.findAll(re"(.{0,70})(\s|$)"):
      ss.add(m.strip(leading=false))
    result = ss.join("\n")

proc type_uri(uri: string): char =
  if uri.match(re"(.*)/0/(.*)"): return '0'
  elif uri.match(re"(.*)/1/(.*)"): return '1'
  elif uri.match(re"(.*)/7/(.*)"): return '7'
  elif uri.match(re"(.*)/8/(.*)"): return '8'
  elif uri.match(re"(.*)/9/(.*)"): return '9'
  elif uri.match(re"(.*)/h/(.*)"): return 'h'
  elif uri.match(re"(.*)/I/(.*)"): return 'I'
  elif uri.match(re"(.*)/g/(.*)"): return 'g'
  else: return '1'

proc dl_uri(uri: string, filename: string, port = 70): string =
  let split = uri.split("/")
  var socket = newSocket()
  var file: string
  if filename.match(re"^##") == true: file = getHomeDir() & filename[2..^1]
  else: file = tmpdir & filename

  try: socket.connect(split[0], Port(port)) # Varying ports necessary?
  except: return "Nothing"

  case type_uri(uri):
    of '0', '1', '7':
      if split.len() > 2:
        socket.send("/" & split[2..^1].join("/") & "\r\L")
      else:
        socket.send("/\r\L")
      var get_lines: seq[string]
      if fileExists(file) == false:
        history.add(uri)
        try:
          while true:
            let line = socket.recvLine(timeout = 30000)
            if line != "": get_lines.add(line)
            else: break
          writeFile(file, get_lines.join("\n"))
        except: return "Nothing"
      return file
    of 'I', 'g', '9':
      if fileExists(file) == false:
        socket.send("/" & split[2..^1].join("/") & "\r\L")
        let f = open(file, fmAppend)
        defer: f.close()
        while true:
          let s = socket.recv(size = 4000)
          if s != "": f.write(s)
          else: break
      return file
    else: return "Nothing"

proc cache_uri(uri: string, port = 70): string =
  let md5 = getMD5(uri)
  result = dl_uri(uri, md5, port)

proc make_dir(file: string): Hole =
  let ls = readFile(file).splitLines()
  result.add(("i", "", "", "(NULL)", ""))
  var c = 1
  for i in ls:
    var lsa: Line
    let cols = i.split("\t")
    if cols.len() > 3:
      lsa.kind = $cols[0][0]
      lsa.text = cols[0][1..^1]
      lsa.path = cols[1]
      lsa.domain = cols[2]
      lsa.port = cols[3]
      result.add(lsa)
    c += 1

proc get_dir(uri: string, port = 70): Hole =
  nav.add(uri)
  let dir = cache_uri(uri, port)
  if fileExists(dir) == false:
    discard nav.pop()
    return errorpage
  else:
    result = make_dir(dir)

proc print_dir(dira: Hole, info: bool, uri: string, page: bool = false) =
  proc process_line(l: Line, c: int) =
    case l.kind
    of "i":
      if info == true: echo "      ", l.text
    of "h": echo "\e[1;1m", c, "\e[1;32m", www, l.text, "\e[0m"
    of "0": echo "\e[1;1m", c, "\e[1;0m", txt, l.text, "\e[0m"
    of "1": echo "\e[1;1m", c, "\e[1;34m", dir, l.text, "\e[0m"
    of "3": echo "\e[1;1m", c, "\e[1;31m", err, l.text, "\e[0m"
    of "7": echo "\e[1;1m", c, "\e[1;33m", fts, l.text, "\e[0m"
    of "8": echo "\e[1;1m", c, "\e[1;35m", tel, l.text, "\e[0m"
    of "9": echo "\e[1;1m", c, "\e[1;31m", bin, l.text, "\e[0m"
    of "I": echo "\e[1;1m", c, "\e[1;36m", img, l.text, "\e[0m"
    of "g": echo "\e[1;1m", c, "\e[1;36m", img, l.text, "\e[0m"
    else: echo "  ??  ", l.text

  if page == false:
    var c = 0
    for i in dira[0..^1]:
      process_line(i, c)
      c += 1
  else:
    let t_height = terminalHeight()
    var dircopy = dira
    var c = 0
    while true:
      if dircopy.len() > t_height:
        let chunk = dircopy[0..t_height-2]
        dircopy.delete(0, t_height-2)
        for i in chunk:
          process_line(i, c)
          c += 1
        case getch():
          of 'q': break
          else: discard
      else:
        for i in dircopy:
          process_line(i, c)
          c += 1
        break

proc do_file(dira: Hole, num: string): string =
  let line = dira[num.parseInt()]
  let link = line.domain & "/" & line.kind & line.path
  result = cache_uri(link, line.port.parseInt())

proc pipe_or_dl(uri: string, port: int): void =
  stdout.write("Pipe? y/n: ")
  let ans = getch()
  if ans == 'y':
    stdout.write("To what? ")
    let pipeto = readLine(stdin)
    discard execShellCmd(pipeto & " " & cache_uri(uri, port))
  else:
    echo "Downloading..."
    let
      name = uri.split("/")[^1]
      f = "##" & uri.split("/")[^1]
    if fileExists(getHomeDir() & name) == false:
      echo "Downloaded to ", dl_uri(uri, f, port)
    else: echo "Error. File already exists."

proc main_loop(uri: string, port = 70) =
  let uri = uri.replace(re"gopher://", "")
  var dira: Hole

  case type_uri(uri):
  of '0':
    let file = cache_uri(uri, port)
    if file != "Nothing":
      echo readFile(file)
      let newuri = uri.split("/")[0..^2].join("/")
      dira = get_dir(newuri, port)
    else: print_dir(errorpage, true, uri)
  of '9', 'I', 'g': pipe_or_dl(uri, port)
  else:
    dira = get_dir(uri, port)
    print_dir(dira, true, uri, auto_page)

  while true:
    echo "\n\e[33m=== " & uri & " ==="
    stdout.write("\e[33m>\e[0m ")
    let x = readLine(stdin).split()
    var y: int
    discard parseInt(x[0], y)

    if y > 0 and y <= dira.len():
      let
        newuri = dira[y].domain & "/" & dira[y].kind & dira[y].path
        newport = dira[y].port.parseInt()
      case dira[y].kind
      of "0":
        let file = cache_uri(newuri, newport)
        if file != "Nothing":
          let text = readFile(file)
          if text.split("\n").len() > terminalHeight():
            discard execShellCmd("$PAGER " & file)
          else: echo text
        else: print_dir(errorpage, true, uri)
      of "1": main_loop(newuri, newport)
      of "7":
        stdout.write("Enter your query: ")
        let q = readLine(stdin)
        let path = dira[y].path.split("?")[0]
        let link = dira[y].domain & "/7" & path & "\t" & q
        main_loop(link, newport)
      of "8":
        let path = dira[y].domain & " " & dira[y].port
        echo "Telnet: ", path
        # discard execShellCmd("telnet " & path) # Alternative
      of "9", "I", "g": pipe_or_dl(newuri, newport)
      of "h": openDefaultBrowser(dira[y].path[4..^1])
    else:
      case x[0]
      of "go":
        if x.len() > 1:
          if x[1].match(re"(.*)/0/(.*)"): echo readFile(cache_uri(x[1]))
          else: main_loop(x[1])
      of "ls": print_dir(dira, false, uri)
      of "more": print_dir(dira, true, uri, true)
      of "cat":
        if x.len() > 1: echo readFile(do_file(dira, x[1]))
        else: print_dir(dira, true, uri)
      of "fold":
        if x.len() > 1:
          let file = do_file(dira, x[1])
          echo readFile(file).re_wrap
      of "less":
        if x.len() > 1:
          discard execShellCmd("$PAGER " & do_file(dira, x[1]))
      of "b", "back":
        if nav.len() > 1:
          discard nav.pop()
          main_loop(nav.pop())
        else: main_loop(home)
      of "h", "hist", "history":
        for i in history: echo i
      of "home": main_loop(home)
      of "search":
        stdout.write("Enter a search query: ")
        let q = readLine(stdin)
        main_loop("gopher.floodgap.com/7/v2/vs?" & q)
      of "url":
        if x.len() > 1:
          let no = x[1].parseInt()
          if no < dira.len() and no > 0:
            var link: string
            let line = dira[no]
            case line.kind
            of "h": link = line.path[4..^1]
            of "8": link = line.domain & " " & line.port
            else: link = line.domain & "/" & line.kind & line.path
            echo link
        else: echo uri
      of "up":
        let x = uri.split("/")
        if x.len() > 1: main_loop(x[0..^2].join("/"))
      of "tour":
        if x.len() > 1:
          if x[1].match(re"(\d+)-(\d+)"):
            let
              t_range = x[1].split("-")
              st = t_range[0].parseInt()
              en = t_range[1].parseInt()
            if st < dira.len() and en < dira.len() and st > 0 and en > 0:
              for i in st..en:
                let line = dira[i]
                tour.add(line.domain & "/" & line.kind & line.path)
          else:
            for i in x[1..^1]:
              let no = i.parseInt()
              if no < dira.len() and no > 0:
                let line = dira[no]
                tour.add(line.domain & "/" & line.kind & line.path)
        else:
          for i in tour: echo i
      of "n", "next":
        if tour.len() > 0:
          let next = tour[0]
          tour.delete(0)
          main_loop(next)
      of "add":
        if fileExists(bookmarks) == false:
          open(bookmarks, fmWrite).write("")
        stdout.write("Enter a description: ")
        let desc = readLine(stdin)
        let f = open(bookmarks, fmAppend)
        defer: f.close()
        if x.len() > 1:
          var y: int
          discard parseInt(x[1], y)
          if y > 0 and y < dira.len():
            f.writeLine(dira[y].kind & desc & "\t" & dira[y].path & "\t" & dira[y].domain & "\t70")
        else:
          let uri_split = uri.split("/")
          if uri_split.len > 2:
            if uri_split[1] != "":
              let
                kind = uri_split[1]
                path = uri_split[2..^1]
              f.writeLine(kind & desc & "\t" & path & "\t" & uri_split[0] & "\t70")
          else:
            f.writeLine("1" & desc & "\t/\t" & uri_split[0] & "\t70")
      of "marks", "bookmarks":
        if fileExists(bookmarks):
          dira = make_dir(bookmarks)
          print_dir(dira, false, uri, auto_page)
        else: echo "No bookmarks."
      of "dl", "download":
        if x.len() > 1:
          var y: int
          discard parseInt(x[1], y)
          if y > 0 and y < dira.len():
            let newuri = dira[y].domain & "/" & dira[y].kind & dira[y].path
            pipe_or_dl(newuri, dira[y].port.parseInt())
      of "autopage":
        auto_page = not auto_page
      of "clean":
        removeDir(tmpdir)
        createDir(tmpdir)
      of "q", "quit", "exit":
        removeDir(tmpdir)
        quit(QuitSuccess)
      of "help":
        if x.len() > 1:
          case x[1]
          of "go":
            echo "\e[1;31m", "go [url]"
            echo "\e[1;0m", "navigates to the specified url."
          of "ls":
            echo "\e[1;31m", "ls"
            echo "\e[1;0m", "Prints current directory's links without info lines"
          of "cat":
            echo "\e[1;31m", "cat [number]"
            echo "\e[1;0m", "cat without a number will reprint the current uri."
            echo "\e[1;0m", "pass a number with the command to print the specified uri."
          of "fold":
            echo "\e[1;31m", "fold [number]"
            echo "\e[1;0m", "Will print the specified uri, but folded."
          of "less":
            echo "\e[1;31m", "less [number]"
            echo "\e[1;0m", "Opens the specified uri in your pager."
          of "more":
            echo "\e[1;31m", "more"
            echo "\e[1;0m", "Prints the dir page by page."
            echo "\e[1;0m", "q to stop."
          of "back":
            echo "\e[1;31m", "b, back"
            echo "\e[1;0m", "Goes to the previous directory."
          of "history":
            echo "\e[1;31m", "h, hist, history"
            echo "\e[1;0m", "Shows where you've been this session."
          of "home":
            echo "\e[1;31m", "home"
            echo "\e[1;0m", "Goes directly to whatever you have set for home."
          of "search":
            echo "\e[1;31m", "search"
            echo "\e[1;0m", "Prompts for a search query, and searches using Veronica II."
          of "url":
            echo "\e[1;31m", "url [number]"
            echo "\e[1;0m", "No number will print the current uri."
            echo "\e[1;0m", "Give it a number to see the uri of any reference."
          of "up":
            echo "\e[1;31m", "up"
            echo "\e[1;0m", "Goes up one directory."
            echo "\e[1;0m", "i.e. some.gopherhole/1/dir/thing -> some.gopherhole/1/dir"
          of "tour":
            echo "\e[1;31m", "tour [number] [..number]"
            echo "\e[1;0m", "Add references to your tour list."
            echo "\e[1;0m", "Use the next command to navigate them one at a time."
            echo "\e[1;0m", "Accepts one number, multiple numbers, or ranges (i.e. 1-3)"
          of "next":
            echo "\e[1;31m", "n, next"
            echo "\e[1;0m", "Goes to the next item in the tour list."
          of "add":
            echo "\e[1;31m", "add [...number]"
            echo "\e[1;0m", "Add current uri to bookmarks, or add numbered uri."
          of "marks":
            echo "\e[1;31m", "marks, bookmarks"
            echo "\e[1;0m", "Display a list of your bookmarks."
          of "clean":
            echo "\e[1;31m", "clean"
            echo "\e[1;0m", "Clears the cache directory."
          of "quit":
            echo "\e[1;31m", "q, quit, exit"
            echo "\e[1;0m", "Exit the application."
          else: echo "No documentation for that."
          stdout.write("\e[0m")
        else:
          echo "\e[1;33m", "Type a number to navigate to that uri.\n"
          echo "\e[1;31m", "Quick reference:"
          echo "\e[1;0m", "go, ls, cat, fold, more, less, back, history, home"
          echo "\e[1;0m", "add, bookmarks, search, url, up, tour, next, clean\nquit\n"
          echo "\e[1;36m", "Type help (command) for more information."
          echo "\e[1;36m", "Toggle auto_paging with 'autopage'", "\e[0m"

if paramCount() > 0: main_loop(paramStr(1).replace(re"gopher://", ""))
else: main_loop(home)
