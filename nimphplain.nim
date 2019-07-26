# Author: Jacob McBlane
# silentmessengers.org
# Version: 0.0.8
#
# Customize the variables on lines ~30 to fit your needs.
#
# Report any bugs to me. Contact info at my gopherhole.
# Note: There are surely bugs!
#
# Launch the app and type help for instructions.
# 
# TODO: - Add more safety!
#       - Check for uri type when loading initial uri. (Partially in)
#       - Open current directory in pager
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
from re import findAll, re, match

let
 home = "silentmessengers.org"
 tmpdir = "/tmp/nimph/"
 bookmarks = getHomeDir() & ".config/nimphmarks"
 pager = "$PAGER"
 # img_app = "sxiv -a"
 fold_width = 65
 www = " @ "
 txt = " # "
 dir = " / "
 err = " ! "
 fts = " ? "
 tel = " > "
 bin = " $ "
 img = " % "

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
    ("1", "    Visit silentmessengers.org", "/", "silentmessengers.org", "70"),
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
  let file = tmpdir & filename
  var socket = newSocket()

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

proc get_dir(uri: string, port = 70): Hole =
  nav.add(uri)
  let dir = cache_uri(uri, port)
  if fileExists(dir) == false:
    discard nav.pop()
    return errorpage
  else:
    let ls = readFile(dir).splitLines()
    var dira: Hole
    dira.add(("i", "", "", "(NULL)", ""))
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

proc print_dir(dira: Hole, info: bool, uri: string, page: bool = false) =
  proc process_line(l: Line, c: int) =
    case l.kind
    of "i":
      if info == true: echo "      ", l.text
    of "h": echo "\e[1;1m", c, "\e[1;32m", www, l.text, "\e[0m"
    of "0": echo "\e[1;1m", c, "\e[1;37m", txt, l.text, "\e[0m"
    of "1": echo "\e[1;1m", c, "\e[1;34m", dir, l.text, "\e[0m"
    of "3": echo "\e[1;1m", c, "\e[1;31m", err, l.text, "\e[0m"
    of "7": echo "\e[1;1m", c, "\e[1;33m", fts, l.text, "\e[0m"
    of "8": echo "\e[1;1m", c, "\e[1;35m", tel, l.text, "\e[0m"
    of "9": echo "\e[1;1m", c, "\e[1;31m", bin, l.text, "\e[0m"
    of "I": echo "\e[1;1m", c, "\e[1;36m", img, l.text, "\e[0m"
    of "g": echo "\e[1;1m", c, "\e[1;36m", img, l.text, "\e[0m"
    else: echo "  ??  ", l.text

  echo "\e[1;33m", uri, "\e[0m"
  var len_c = 0
  while len_c < uri.len():
    stdout.write "-"
    len_c += 1
  stdout.write("\n\n")

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

proc main_loop(uri: string, port = 70) =
  var dira: Hole

  case type_uri(uri):
  of '0':
    let file = cache_uri(paramStr(1), port)
    if file != "Nothing":
      echo readFile(file)
      let newuri = uri.split("/")[0..^2].join("/")
      dira = get_dir(newuri, port)
    else: print_dir(errorpage, true, uri)
  of '9', 'I', 'g':
    stdout.write("Enter a filename:")
    let f = readLine(stdin)
    echo "Saved to: " & dl_uri(uri, f, port)
    let newuri = uri.split("/")[0..^2].join("/")
    dira = get_dir(newuri, port)
  else:
    dira = get_dir(uri, port)
    print_dir(dira, true, uri, auto_page)

  while true:
    stdout.write("> ")
    let x = readLine(stdin).split()
    var y: int
    discard parseInt(x[0], y)

    if y > 0 and y <= dira.len():
      let newuri = dira[y].domain & "/" & dira[y].kind & dira[y].path
      let newport = dira[y].port.parseInt()
      case dira[y].kind
      of "0":
        let file = cache_uri(newuri, newport)
        if file != "Nothing":
          let text = readFile(file)
          if text.split("\n").len() > terminalHeight():
            discard execShellCmd(pager & " " & file)
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
      of "9", "I", "g":
        stdout.write("Enter a filename: ")
        let f = readLine(stdin)
        echo "Downloaded to ", dl_uri(newuri, f, newport)
      of "h": openDefaultBrowser(dira[y].path[4..^1])
      # of "I", "g": discard execShellCmd(img_app & " " & cache_uri(newuri, newport)) ##Dropped in favor of downloading the image.
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
        # Make this able to open the current dir in less
        if x.len() > 1:
          discard execShellCmd(pager & " " & do_file(dira, x[1]))
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
            let newuri = dira[y].domain & "/" & dira[y].kind & dira[y].path
            f.writeLine(newuri & " :: " & desc)
        else: f.writeLine(uri & "  :: " & desc)
      of "marks", "bookmarks":
        if fileExists(bookmarks): echo readFile(bookmarks)
        else: echo "No bookmarks."
      of "dl", "download":
        if x.len() > 1:
          var y: int
          discard parseInt(x[1], y)
          if y > 0 and y < dira.len():
            let newuri = dira[y].domain & "/" & dira[y].kind & dira[y].path
            stdout.write("Enter a filename: ")
            let name = readLine(stdin)
            echo "Saved to " & dl_uri(newuri, name, dira[y].port.parseInt())
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
            echo "\e[1;37m", "navigates to the specified url."
            stdout.write("\e[0m")
          of "ls":
            echo "\e[1;31m", "ls"
            echo "\e[1;37m", "Prints current directory's links without info lines"
            stdout.write("\e[0m")
          of "cat":
            echo "\e[1;31m", "cat [number]"
            echo "\e[1;37m", "cat without a number will reprint the current uri."
            echo "\e[1;37m", "pass a number with the command to print the specified uri."
            stdout.write("\e[0m")
          of "fold":
            echo "\e[1;31m", "fold [number]"
            echo "\e[1;37m", "Will print the specified uri, but folded."
            stdout.write("\e[0m")
          of "less":
            echo "\e[1;31m", "less [number]"
            echo "\e[1;37m", "Opens the specified uri in your pager."
            stdout.write("\e[0m")
          of "more":
            echo "\e[1;31m", "more"
            echo "\e[1;37m", "Prints the dir page by page."
            echo "\e[1;37m", "q to stop."
            stdout.write("\e[0m")
          of "back":
            echo "\e[1;31m", "b, back"
            echo "\e[1;37m", "Goes to the previous directory."
            stdout.write("\e[0m")
          of "history":
            echo "\e[1;31m", "h, hist, history"
            echo "\e[1;37m", "Shows where you've been this session."
            stdout.write("\e[0m")
          of "home":
            echo "\e[1;31m", "home"
            echo "\e[1;37m", "Goes directly to whatever you have set for home."
            stdout.write("\e[0m")
          of "search":
            echo "\e[1;31m", "search"
            echo "\e[1;37m", "Prompts for a search query, and searches using Veronica II."
            stdout.write("\e[0m")
          of "url":
            echo "\e[1;31m", "url [number]"
            echo "\e[1;37m", "No number will print the current uri."
            echo "\e[1;37m", "Give it a number to see the uri of any reference."
            stdout.write("\e[0m")
          of "up":
            echo "\e[1;31m", "up"
            echo "\e[1;37m", "Goes up one directory."
            echo "\e[1;37m", "i.e. some.gopherhole/1/dir/thing -> some.gopherhole/1/dir"
            stdout.write("\e[0m")
          of "tour":
            echo "\e[1;31m", "tour [number] [..number]"
            echo "\e[1;37m", "Add references to your tour list."
            echo "\e[1;37m", "Use the next command to navigate them one at a time."
            echo "\e[1;37m", "Accepts one number, multiple numbers, or ranges (i.e. 1-3)"
            stdout.write("\e[0m")
          of "next":
            echo "\e[1;31m", "n, next"
            echo "\e[1;37m", "Goes to the next item in the tour list."
            stdout.write("\e[0m")
          of "add":
            echo "\e[1;31m", "add [...number]"
            echo "\e[1;37m", "Add current uri to bookmarks, or add numbered uri."
            stdout.write("\e[0m")
          of "marks":
            echo "\e[1;31m", "marks, bookmarks"
            echo "\e[1;37m", "Display a list of your bookmarks."
            stdout.write("\e[0m")
          of "clean":
            echo "\e[1;31m", "clean"
            echo "\e[1;37m", "Clears the cache directory."
            stdout.write("\e[0m")
          of "quit":
            echo "\e[1;31m", "q, quit, exit"
            echo "\e[1;37m", "Exit the application."
            stdout.write("\e[0m")
          else: echo "No documentation for that."
        else:
          echo "\e[1;33m", "Type a number to navigate to that uri.\n"
          echo "\e[1;31m", "Quick reference:"
          echo "\e[1;37m", "go, ls, cat, fold, more, less, back, history, home"
          echo "\e[1;37m", "add, bookmarks, search, url, up, tour, next, clean\nquit\n"
          echo "\e[1;36m", "Type help (command) for more information.", "\e[0m"
          echo "\e[1;36m", "Toggle auto_paging with 'autopage'", "\e[0m"

if paramCount() > 0: main_loop(paramStr(1))
else: main_loop(home)
