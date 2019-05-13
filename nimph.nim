# Author: Jacob McBlane
# gopher.silentmessengers.org
# Version: 0.0.35
#
# Depends upon:
#           * curl
#           * fold
# These should be already installed on any linux system.
# Customize the variables on lines ~33 to fit your needs.
# Customize lines ~115 for formatting output
#
# Report any bugs to me. Contact info at my gopherhole.
# Note: There are surely bugs!
#
# Launch the app and type help for instructions.
# 
# TODO: - Add more safety!
#       - Would like the image program to be asynchronous.
#       - Check for uri type when loading initial uri. (Partially in)
#       - Open current directory in pager

import os, osproc, re
import md5, parseutils, strutils

var
 tour = newSeq[string]()
 nav = newSeq[string]()
 history = newSeq[string]()
 t_height: int

let
 home = "gopher.silentmessengers.org"
 tmpdir = "/tmp/nimph/"
 bookmarks = getHomeDir() & ".config/nimphmarks"
 pager = "$PAGER"
 img_app = "sxiv -a"
 browser = "$BROWSER"
 fold_width = "65"

if dirExists(tmpdir) == false:
  createDir(tmpdir)

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

proc dl_uri(uri: string, filename: string): string =
  let file = tmpdir & filename
  if fileExists(file) == false:
    history.add(uri)
    let prefix = "gopher://" & uri
    discard execShellCmd("curl -s --connect-timeout 10 \"" & prefix & "\" --output " & file)
  return file

proc cache_uri(uri: string): string =
  let md5 = getMD5(uri)
  return dl_uri(uri, md5)

proc get_dir(uri: string): seq[seq[string]] =
  nav.add(uri)
  let dir = cache_uri(uri)
  if fileExists(dir) == false:
    discard nav.pop()
    return @[@["", "", "", "", ""],
            @["i", "", "", "Err", ""],
            @["i", "", "", "Err", ""],
            @["i", "Error:", "", "Err", ""],
            @["i", "------", "", "Err", ""],
            @["i", "", "", "Err", ""],
            @["i", "Couldn't navigate to " & uri, "", "Err", ""],
            @["i", "", "", "Err", ""],
            @["i", "Looks like curl timed out or something.", "", "Err", ""],
            @["i", "", "", "Err", ""],
            @["1", "    Visit gopher.silentmessengers.org", "/", "gopher.silentmessengers.org", "70"],
            @["7", "    Search w/ Veronica II", "/v2/vs", "gopher.floodgap.com", "70"],
            @["i", "", "", "Err", ""],
            @["i", "", "", "Err", ""]]
  else:
    let ls = readFile(dir).split("\n")
    var dira = newSeq[seq[string]]()
    dira.add(@["i", "", "", "(NULL)", ""])
    var c = 1
    for i in ls:
      var lsa = newSeq[string]()
      let cols = i.split("\t")
      if cols.len() > 3:
        lsa.add($cols[0][0])
        lsa.add(cols[0][1..high(cols[0])])
        lsa.add(cols[1])
        lsa.add(cols[2])
        lsa.add(cols[3])
        dira.add(lsa)
      c += 1
    return dira

proc print_dir(dira: seq[seq[string]], info: bool, uri: string) =
  echo "\e[1;33m", uri, "\e[0m"
  var len_c = 0
  while len_c < uri.len():
    stdout.write "-"
    len_c += 1
  stdout.write("\n\n\n")
  var c = 1
  for i in dira[1..high(dira)]:
    case i[0]
    of "i":
      if info == true: echo "      ", i[1]
    of "h": echo "\e[1;1m", c, "\e[1;32m", " 爵 ", i[1], "\e[0m"
    of "0": echo "\e[1;1m", c, "\e[1;37m", "   ", i[1], "\e[0m"
    of "1": echo "\e[1;1m", c, "\e[1;34m", "   ", i[1], "\e[0m"
    of "3": echo "\e[1;1m", c, "\e[1;31m", "   ", i[1], "\e[0m"
    of "7": echo "\e[1;1m", c, "\e[1;33m", "   ", i[1], "\e[0m"
    of "8": echo "\e[1;1m", c, "\e[1;35m", "   ", i[1], "\e[0m"
    of "9": echo "\e[1;1m", c, "\e[1;31m", "   ", i[1], "\e[0m"
    of "I": echo "\e[1;1m", c, "\e[1;36m", "   ", i[1], "\e[0m"
    of "g": echo "\e[1;1m", c, "\e[1;36m", "   ", i[1], "\e[0m"
    else: echo "  ??  ", i[1]
    c += 1

proc get_image(uri: string): int =
  let x = cache_uri(uri)
  return execShellCmd(img_app & " " & x)

proc do_file(dira: seq[seq[string]], num: string): string =
  var no: int
  discard parseInt(num, no)
  let line = dira[no]
  let link = line[3] & "/" & line[0] & line[2]
  let file = cache_uri(link)
  return file

proc main_loop(uri: string) =
  # This is extensible.
  case type_uri(uri):
  of '0':
    let file = cache_uri(paramStr(1))
    let text = readFile(file)
    echo readFile(file)
  else: discard

  let dira = get_dir(uri)
  print_dir(dira, true, uri)
  while true:
    stdout.write("> ")
    let x = readLine(stdin).split()
    var y: int
    discard parseInt(x[0], y)

    if y > 0 and y <= dira.len():
      let newuri = dira[y][3] & "/" & dira[y][0] & dira[y][2]
      case dira[y][0]
      of "0":
        discard parseInt(execProcess("tput lines"), t_height)
        let file = cache_uri(newuri)
        let text = readFile(file)
        if text.split("\n").len() > t_height:
          discard execShellCmd(pager & " " & file)
        else: echo text
      of "1":
        main_loop(newuri)
      of "7":
        stdout.write("Enter your query: ")
        let q = readLine(stdin)
        let path = dira[y][2].split("?")
        let link = dira[y][3] & "/7" & path[0] & "?" & q
        main_loop(link)
      of "8":
        let path = dira[y][3] & " " & dira[y][4]
        let a = execShellCmd("telnet " & path)
        if a == 1: echo path
      of "9":
        stdout.write("Enter a filename: ")
        let f = readLine(stdin)
        let file = dl_uri(newuri, f)
        echo "Downloaded to ", file
      of "h":
        let link = dira[y][2][4..high(dira[y][2])]
        discard execShellCmd(browser & " " & link)
      of "I", "g":
        discard get_image(newuri)
    else:
      case x[0]
      of "go":
        if x.len() > 1:
          if x[1].match(re"(.*)/0/(.*)"):
            let file = cache_uri(x[1])
            let text = readFile(file)
            echo readFile(file)
          else: main_loop(x[1])
      of "ls": print_dir(dira, false, uri)
      of "cat":
        if x.len() > 1:
          let file = do_file(dira, x[1])
          let text = readFile(file)
          echo readFile(file)
        else: print_dir(dira, true, uri)
      of "fold":
        if x.len() > 1:
          let file = do_file(dira, x[1])
          let text = execShellCmd("fold -w " & fold_width & " -s " & file)
      of "less":
        # Make this able to open the current dir in less
        if x.len() > 1:
          let file = do_file(dira, x[1])
          let i = execShellCmd(pager & " " & file)
      of "b", "back":
        if nav.len() > 1:
          let current = nav.pop()
          main_loop(nav.pop())
        else: main_loop(home)
      of "h", "hist", "history":
        for i in history:
          echo i
      of "home":
        main_loop(home)
      of "search":
        stdout.write("Enter a search query: ")
        let q = readLine(stdin)
        let link = "gopher.floodgap.com/7/v2/vs?" & q
        main_loop(link)
      of "url":
        if x.len() > 1:
          var no: int
          var link: string
          discard parseInt(x[1], no)
          if no < dira.len() and no > 0:
            let line = dira[no]
            case line[0]
            of "h":
              link = line[2][4..high(line[2])]
            of "0", "1", "7", "9", "I", "g":
              link = line[3] & "/" & line[0] & line[2]
            of "8":
              link = line[3] & " " & line[4]
            echo link
        else: echo uri
      of "up":
        var a: int
        let x = uri.split("/")
        if x.len() > 1:
          a = x.len() - 2
          main_loop(x[0..a].join("/"))
      of "tour":
        if x.len() > 1:
          if x[1].match(re"(.*)-(.*)"):
            let t_range = x[1].split("-")
            var st: int
            var en: int
            discard parseInt(t_range[0], st)
            discard parseInt(t_range[1], en)
            if st < dira.len() and en < dira.len() and st > 0 and en > 0:
              for i in st..en:
                let line = dira[i]
                tour.add(line[3] & "/" & line[0] & line[2])
          else:
            for i in x[1..high(x)]:
              var no: int
              discard parseInt(i, no)
              if no < dira.len() and no > 0:
                let line = dira[no]
                tour.add(line[3] & "/" & line[0] & line[2])
        else:
          for i in tour:
            echo i
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
            let newuri = dira[y][3] & "/" & dira[y][0] & dira[y][2]
            f.writeLine(newuri & " :: " & desc)
        else: f.writeLine(uri & "  :: " & desc)
      of "marks", "bookmarks":
        if fileExists(bookmarks):
          let x = readFile(bookmarks)
          echo x
        else: echo "No bookmarks."
      of "dl", "download":
        if x.len() > 1:
          var y: int
          discard parseInt(x[1], y)
          if y > 0 and y < dira.len():
            let newuri = dira[y][3] & "/" & dira[y][0] & dira[y][2]
            stdout.write("Enter a filename: ")
            let name = readLine(stdin)
            let f = dl_uri(newuri, name)
            echo "Saved to " & f
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
          of "quit":
            echo "\e[1;31m", "q, quit, exit"
            echo "\e[1;37m", "Exit the application."
            stdout.write("\e[0m")
          else: echo "No documentation for that."
        else:
          echo "\e[1;33m", "Type a number to navigate to that uri.\n"
          echo "\e[1;31m", "Quick reference:"
          echo "\e[1;37m", "go, ls, cat, fold, less, back, history, home"
          echo "\e[1;37m", "add, bookmarks, search, url, up, tour, next, quit\n"
          echo "\e[1;36m", "Type help (command) for more information.", "\e[0m"

if paramCount() > 0: main_loop(paramStr(1))
else: main_loop(home)
