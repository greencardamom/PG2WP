@load "readfile"
@load "filefuncs"


#----------------------------------------------------
#
# Wget HTML source to a file
#
#----------------------------------------------------
function wget_file(url, out	,command, dump, filename)
{

  filename = out exten(url)

  if(exists(filename)) {
    dump = readfile(filename)
    if(Debug)
      print "CACHED: awget " url " > " filename
    return dump
  }

  if(Debug)
    print "awget " url " > " filename

  dump = awget(url)

  if(length(dump) > 0) {
    print dump > filename
    close(filename)
    dump = ""
    return 1
  }
  else
    return 0
 
}

#----------------------------------------------------
#
# Wget HTML source to a string 
# temp = a temp directory 
#
#----------------------------------------------------
function wget_str(url, temp	,command, dump, filename)
{

  filename = temp exten(url)

  if(exists(filename)) {
    dump = readfile(filename)
    if(Debug)
      print "CACHED: awget " url " > " filename
    return dump
  }

  if(Debug)
    print "awget " url " > " filename

  dump = awget(url)

  if(length(dump) > 0) {
    print dump > filename
    close(filename)
    return dump
  }
  else
    return 0

}

#----------------------------------------------------
#
# Wget HTTPS HTML source to a string 
# temp = a temp directory 
#
#----------------------------------------------------
function wget_ssl(url, temp	,command, dump, filename)
{

  filename = temp exten(url)

  command = sprintf("%s --no-check-certificate -q -O- \"%s\" > \"%s\"", WGET, url, filename)

  if(exists(filename)) {
    dump = readfile(filename)
    if(Debug)
      print "CACHED: " command
    return dump
  }

  if(Debug)
    print command

  system(command)
  close(command)

  dump = readfile(filename)

  if(length(dump) > 0) {
    return dump
  }
  else
    return 0
}

# Create a file extension based on url type
#
function exten(str)
{

  if(match(str,"Special:Search")) {
    StatS["Special:Search"]++
    return ".srch"
  }
  if(match(str,"Special:Export")) {
    StatS["Special:Export"]++
    return ".exp"
  }
  if(match(str,"openlibrary")) {
    StatS["Open Library"]++
    return ".ol"
  }
  if(match(str,"ext-lnk-discover")) {
    StatS["Category Scan"]++
    return ".cat"
  }
  if(match(str,"prop=template")) {
    StatS["API template"]++
    return ""
  }
  if(match(str,"prop=langlinks")) {
    StatS["API langlinks"]++
    return ""
  }
  if(match(str,"prop=links")) {
    StatS["API links"]++
    return ""
  }
  if(match(str,"prop=externallinks")) {
    StatS["API externallinks"]++
    return ""
  }
  if(match(str,"list=backlinks")) {
    StatS["API backlinks"]++
    return ""
  }
  else {
    StatS["Article"]++
    return ".art"
  }

}

#----------------------------------------------------
#
# Wiki source ie. not HTML 
#  temp = temp directory
#  Sets global FlaG["redirect"] if true. Must be reset to 0 elsewhere.
#----------------------------------------------------
function wget_wiki_source(url, temp	,str,a,b,c,d,i,j,n,json)
{

  str = wget_str(url, temp)

 # If redirect..
  if(tolower(str) ~ "#[ ]{0,2}redirect") {

    c = split(url, n, "/")
    json = wiki_api_parse(n[c], "links")
    j = split(json,a,"[")
    while(i < j) {
      i++
      if(match(a[i],"\"redirects\",[0-9]{1,3},\"to\"")) {
        gsub(/[\\]\"/,"%22",a[i])
        split(a[i],d,"\"")
        temp = PG_TEMP encode(d[8])         

        Title = d[8]

        if(Debug)
          print "      --> redirect <--"

        str = wget_str("http://en.wikipedia.org/wiki/Special:Export/" encode(d[8]), temp)
        i = j

        FlaG["redirect"] = "Yes"

       # Set Global title
#        match(str,/<redirect title=\"[^\"]*\"/,a)
#        split(a[0],b,"\"")
#        Title = b[2]  

      }
    }
  }
  
  if(str != 0) {

  # Set FlaG["hatnote"], but check for it only certain cases
    if(FlaG["dab"] == "No" && FlaG["hatnote"] == "No") {

      if(Debug)
        print "      ---hatnote check---"

      if(FlaG["redirect"] == "Yes") {
        json = wiki_api_parse(encode(d[8]), "templates")
      } else {  
        c = split(url, n, "/")
        json = wiki_api_parse(n[c], "templates")
      }
      if(json ~ "Module:Hatnote")          
        FlaG["hatnote"] = "Yes" 
    }

  # Set global var Title
    if(FlaG["redirect"] == "No") {
      match(str,/<title>[^<]*</,a)
      split(a[0],b,">|<")
      Title = b[3]  
    }

  # Extract the wikisource portion from the XML
    match(str,"<text xml.*",a)
    split(a[0],b,">")
    gsub("</text","",b[2])
    gsub(/&lt;/,"<",b[2])
    gsub(/&gt;/,">",b[2])
    gsub(/&quot;/,"\"",b[2])
    gsub(/&amp;/,"\\&",b[2])

    return b[2]
  }
  else
    return 0
}

# WikiMedia API - returns a formatted JSON file. Uses JSON.awk
#  http://www.mediawiki.org/wiki/API:Parsing_wikitext
#  https://github.com/step-/JSON.awk
#
#  Note: certain characters will *return* escaped by the MediaWiki API: " \ / 
#        See http://tools.ietf.org/html/rfc7159#section-7
#            https://bugzilla.wikimedia.org/show_bug.cgi?id=72734
#
#  Note: certain characters need to be *sent* escaped to the MW API: & = %26
#
#  prop = templates, links, etc.. see link above for possible switches
#  name = URL-encoded name of article
#
function wiki_api_parse(name, prop	,jsonin,jsonout,apiurl,command,json,currenttime)
{

    jsonin = PG_TEMP name "." prop ".json.in"
    jsonout = PG_TEMP name "." prop ".json.out"

    gsub(/[$]/,"",jsonin)  
    gsub(/[$]/,"",jsonout)   

    apiurl = "http://en.wikipedia.org/w/api.php?action=parse&page=" name "&prop=" prop "&format=json&utf8=1&redirects=1&maxlag=5&continue="
    wget_file(apiurl, jsonin)
    command = sprintf("echo -e \"%s\\n\" | %s -f %s > \"%s\"", jsonin, AWK, JSON, jsonout)
    system(command)
    close(command)
    json = readfile(jsonout)

    if(json ~ "seconds lagged") {

      APIloop[name]++
      StatS["API timeout"]++
      currenttime = strftime("%H:%M:%S")

      if( APIloop[name] > 6 ) {
        print "Error: Infinite loop in wiki_api_parse" > "/dev/stderr"
        return ""
      }

      print "Warning: Wikipedia API (parse) lagging for " name ". Trying again in 30 secs (attempt #" APIloop[name] "). Current time: " currenttime > "/dev/stderr"
      #print "--------------"  > "/dev/stderr"
      #print json  > "/dev/stderr"
      #print "--------------"  > "/dev/stderr"

      sleep(30)

      rmfile(jsonin)      
      rmfile(jsonout)      

      json = wiki_api_parse(name, prop)
 
    } 

    return json

}

# Get list of backlinks, redirects only.
#  
function wiki_api_backlinks(name      ,jsonin,jsonout,apiurl,command,json,currenttime)
{

    jsonin = PG_TEMP name ".backlinks.json.in"
    jsonout = PG_TEMP name ".backlinks.json.out"

    gsub(/[$]/,"",jsonin)  
    gsub(/[$]/,"",jsonout)   

    apiurl = "http://en.wikipedia.org/w/api.php?action=query&list=backlinks&bltitle=" name "&bllimit=500&blfilterredir=redirects&continue=&format=json&utf8=1&maxlag=5"
    wget_file(apiurl, jsonin)
    command = sprintf("echo -e \"%s\\n\" | %s -f %s > \"%s\"", jsonin, AWK, JSON, jsonout)
    system(command)
    close(command)
    json = readfile(jsonout)

    if(json ~ "seconds lagged") {

      APIloop[name]++
      StatS["API timeout"]++
      currenttime = strftime("%H:%M:%S")

      if( APIloop[name] > 6 ) {
        print "Error: Infinite loop in wiki_api_backlinks" > "/dev/stderr"
        return ""
      }

      print "Warning: Wikipedia API (backlinks) lagging for " name ". Trying again in 30 secs (attempt #" APIloop[name] "). Current time: " currenttime > "/dev/stderr"
      #print "--------------"  > "/dev/stderr"
      #print json  > "/dev/stderr"
      #print "--------------"  > "/dev/stderr"

      sleep(30)

      rmfile(jsonin)      
      rmfile(jsonout)      

      json = wiki_api_backlinks(name)
 
    } 

    return json
}

#----------------------------------------------------
#
# Category list of entries
#
#----------------------------------------------------
function wget_category(url, temp	,str,a)
{
  str = wget_ssl(url, temp)
  if(str != 0) {
    split(str,a,"<!-- Start -->|<!-- End -->")
    gsub(/^[ \t\r\n]+/,"",a[2]) # rm lead/trail whitespace & newline
    gsub(/[ \t\r\n]+$/,"",a[2])
    return a[2]   
  }
  else
    return 0
}

#----------------------------------------------------
#
# Make a directory ("mkdir -p dir")
#
#----------------------------------------------------
function mkdir(dir	,command, ret, var, cwd)
{

  command = MKDIR " -p \"" dir "\" 2>/dev/null"
  while ((command | getline var) > 0) {
  }
  close(command)

  cwd = ENVIRON["PWD"]

  ret = chdir(dir)
  if (ret < 0) {
    printf("Could not create %s (%s)\n", dir, ERRNO) > "/dev/stderr"
  }
  ret  = chdir(cwd)
  if (ret < 0) {
    printf("Could not chdir to %s (%s)\n", cwd, ERRNO) > "/dev/stderr"
  }

}

#----------------------------------------------------
#
# Move a file.  Default: "mv -f origin target"
#               Options: "mv [opt] origin target"
#
#----------------------------------------------------
function mv(origin, target, opt		,command, var)
{

  if(opt == "") {
    command = MV " -f \"" origin "\" \"" target "\" 2>/dev/null"
  }else{
    command =  MV " " opt " \"" origin "\" \"" target "\" 2>/dev/null"
  }

  while ((command | getline var) > 0) {
  }
  close(command)

}

#----------------------------------------------------
#
# Remove a directory + contents ("rm -r dirname")
#
#----------------------------------------------------
function rmdir(dir	,command, ret, var)
{

  command = RM " -r \"" dir "\" 2>/dev/null"

  while ((command | getline var) > 0) {
  }
  close(command)

  ret = chdir(dir)
  if (ret == 0 || ret > 0) {
    printf("Unable to delete directory %s (%s)\n", dir, ERRNO) > "/dev/stderr"
    return 0
  }
  return 1
}

#----------------------------------------------------
#
# Remove directory contents ("rm -f dirname/*")
#
#----------------------------------------------------
function rmfile(dirfile		,command, ret, var)
{

  command = RM " -f \"" dirfile "\" 2>/dev/null"
  while ((command | getline var) > 0) {
  }
  close(command)

  if(Debug)
    print command

}

#----------------------------------------------------
#
# mylog
#
#----------------------------------------------------

function mylog(file,msg		,mylogfp,mylogname) 
{ 

  mylogname = PG_TEMP "mylog"

  if(msg ~ /CLOSE/) {
    if(WP["findtype"] !~ /^Found/) { # Only add tempfile entries if not "Found"
      if(exists(mylogname)) {
        mylogfp = readfile(mylogname)
        printf("%s", mylogfp) >> file
        close(file)
        rmfile(mylogname)
      }  
    } else {
        if(exists(mylogname))
          rmfile(mylogname)
      }
  } else if(msg ~ /Found/) {
    print msg >> file
    close(file) 
  } else {                           # Hold the "Possibles" in a tempfile
    print msg >> mylogname
    close(mylogname)
  }

}


# URL-encode a string
#   via http://rosettacode.org/wiki/URL_encoding#AWK
#
# This breaks OpenLibrary searches.
#
function urlencode(str    ,c, len, res, ord) {
  len = length(str)
  res = ""

  for (i = 0; i <= 255; i++)
    ord[sprintf("%c", i)] = i

  for (i = 1; i <= len; i++) {
    c = substr(str, i, 1);
    #if (c ~ /[0-9A-Za-z]/)
    if (c ~ /[-._*0-9A-Za-z]/)
      res = res c
    else if (c == " ")
      res = res "+"
    else
      res = res "%" sprintf("%02X", ord[c])
    }
    return res
}

#----------------------------------------------------
#
# Simulation of sleep
# http://rosettacode.org/wiki/Sleep#AWK
#
#----------------------------------------------------
function sleep(seconds		,t)
{
    t = systime()
    while ( systime() < t + seconds ) {}
}
 

#----------------------------------------------------
#
# Check if file or directory exists, even 0-length. 
#   return 0 if not exist
#
#----------------------------------------------------
function exists(file    ,line, msg)
{
        if ( (getline line < file) == -1 )
        {
                # "Permission denied" is for MS-Windows
                msg = (ERRNO ~ /Permission denied/ || ERRNO ~ /a directory/) ? "1" : "0"
                close(file)
                return msg
        }
        else {
                close(file)
                return 1
        }
}


#----------------------------------------------------
#
# Trimfile. Ensure total filename doesn't exceed 250 chars
#   Removes extra characters from the start of article-name portion of str.
#
#----------------------------------------------------
function trimfile(str   ,a,l,i,j,p)
{

  if(length(str) < 251)
    return str

  a = substr(str, length(PG_TEMP))

  l = (length(a) + length(PG_TEMP)) - 250

  while(i < length(a)) {
    i++
    if(i > l) {
      j++
      p[j] = substr(a, i, 1)
    }
  }

  return PG_TEMP join(p, 1, length(p), SUBSEP)

}




#----------------------------------------------------
# Approximate (fuzzy) matching using agrep
#
#  source  = source text
#  search  = text to search for in source
#  percent = maximum error rate percentage of search. 
#            ie. if source is 12 characters and max error rate is 25%, set to ".25"
#                and it will return a match if up to 3 characters are wrong.
#
#  Error rate is hard coded: max out at "6" on the upper and "1" on the lower.
#  Agrep set to case-insensitive
#
#  Return 0 if no match, otherwise number of matches
#
#----------------------------------------------------
function agrep(source, search, percent   ,errorlimit,tempfile,results)
{

 # Limit # of errors to 25% of length of str, or no more than 6, whichever is less
  if(length(search) > 24)
    errorlimit = 6
  else
    errorlimit = int(length(search) * percent)
  if(errorlimit < 2) {
    if(length(search) < 6)
      errorlimit = 1
    else
      errorlimit = 2
  }

  gsub("\"","\\\"",search)

  command = AGREP " -i -k -c -" errorlimit  " \"" search "\""
  print source |& command
  close(command, "to")
  command |& getline results
  close(command)

  if(results > 0)
    return results
  else
    return 0
}

#----------------------------------------------------
# Strip leading/trailing whitespace
#----------------------------------------------------
function strip(str)
{
        gsub(/^[ \t]+/,"",str) # rm lead/trail whitespace
        gsub(/[ \t]+$/,"",str)
        return str
}


#----------------------------------------------------
# Merge an array of strings into a single string
# Source: https://www.gnu.org/software/gawk/manual/html_node/Join-Function.html
#
#----------------------------------------------------
function join(array, start, end, sep,    result, i)
{
    if (sep == "")
       sep = " "
    else if (sep == SUBSEP) # magic value
       sep = ""
    result = array[start]
    for (i = start + 1; i <= end; i++)
        result = result sep array[i]
    return result
}



#
# Run a system command and store result in a variable
#   eg. googlepage = sys2var("wget -q -O- http://google.com")
# Supports pipes inside command string. Stderr is sent to null.
# If command fails return null
#
function sys2var(command        ,fish, scale, ship) {

         command = command " 2>/dev/null"
         while ( (command | getline fish) > 0 ) {
             if ( ++scale == 1 )
                 ship = fish
             else
                 ship = ship "\n" fish
         }
         close(command)
         return ship
}

#
# Webpage to variable
#
function awget(url      ,command) {

        command = WGET " --no-check-certificate --user-agent=\"" API_AGENT "\" -q -O- \"" url "\""
        return sys2var(command)
}


