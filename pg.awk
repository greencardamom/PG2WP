#!/bin/awk -f 

#################################################################
# PG2WP
# pg2wp.awk
# (gawk)
#
# Naming conventions: lowercase                 = Local variable eg. "str[i]" (arrays and numbers)
#                     Capital first letter      = Global variable eg. Stamp (defined in init.awk)
#                     Cap first and last letter = Global array eg. DaB or WorkS or PG
#                     Cap last letter           = Local array with associative index eg. localS["files"]
#                     ALL CAPS                  = Static defined in init.awk eg. PG_HOME or WGET
#                                                 Also, Awk's own internal variables eg. ARGV, RS, FS etc
#
# Copyright (c) User:Green Cardamom (on en.wikipeda.org)
# October 2014
# License: MIT (see LICENSE file included with this package)
#################################################################

@include "getopt.awk"     # from /usr/share/awk
@include "init.awk"       # custom paths and static
@include "library.awk"    # standard functions
@include "convert.awk"    # convert PG name 

BEGIN {

  # If an option conflicts with Awk's own, need to run with a "--" eg. pg.awk -- -f filename 

  while ((c = getopt(ARGC, ARGV, "z:k:j:")) != -1) {
    opts++
    if(c == "j") {
      datafile = PG_HOME Optarg
      if(! exists(datafile)) {
        printf("File does not exist: %s\n",datafile)
        exit 1
      }
    }
    if(c == "k") 
      outfile = PG_HOME Optarg

    if(c == "z")
      PG_LOG = PG_HOME Optarg
  }

  if(opts == 0) 
    usage()

  if(outfile == "" || datafile == "")
    usage()

  Debug = 1 # On all the time by default, recommended though not required.

  t = strftime("%Y-%m-%d %H:%M:%S") 
  print t >> PG_LOG


 # See 0README step 4. for how to create "match" files from previous runs of PG2WP so work is not repeated in future runs.
  Foundfilename = PG_HOME "match-found"
  if(exists(Foundfilename)) 
    Found = 1
  else
    Found = ""
  Fpfilename = PG_HOME "match-false-positive"
  if(exists(Fpfilename)) 
    FalsePositives = 1
  else
    FalsePositives = ""
  Posfilename = PG_HOME "match-possible"
  if(exists(Posfilename)) 
    Possibles = 1
  else
    Possibles = ""

  main(datafile)

  t = strftime("%Y-%m-%d %H:%M:%S") 
  print t >> PG_LOG

  stats()

}  

function main(datafile	,rawname,rawstr,str,wikipage,article,findtype,type,a,b,d,di,ld,wpdates,pgdates,numofbooks)
{

 # Read in one name
  while ((getline rawname < datafile ) > 0) {

    split(convert(rawname),str,"|")         # See convert.awk

   # Initialize globals 
    delete WorkS              # Empty array of author's book titles found in catalog.csv. 
    delete DaB                # Empty array of articles found on a Wiki dab page
    delete FlaG		      # Empty array of global boolean flags
    delete WlH		      # Empty array of "What links here" links
    get_pg_date(str[2])       # Fill variables PG["birth"], PG{"deat'h"] and FlaG["fuzzydate"] 
    PG["name"]  = str[1]      # Name created by convert.awk - a best-guess starting point. Static doesn't change.
    PG["ename"] = encode(PG["name"])  # URL-encoded name. Dynamic, may change after redirects, searches etc
    PG["uname"] = PG["name"]  # URL-decoded name. Dynamic, will change along with ename.
    PG["fullname"] = str[3]   # Name from catalog.csv prior to convert.awk - static
    WP["name"]  = UNK         # What we are trying to find. UNK = "NA" (ie. no name found)
    WP["birth"] = ""
    WP["death"] = ""
    WP["findtype"] = ""       # Debug info on how the program determined the match
    WP["template"] = ""       # If article has {{Gutenberg author}} template (1 or 0)
    FlaG["redirect"] = "No"   # Denote a Wikipedia #redirect page
    FlaG["search"] = "No"     # Denote a Wikipedia Special:Search page
    FlaG["dab"] = "No"        # Denote a Wikipedia disambiguation page
    FlaG["hatnote"] = "No"    # Denote a Wikipedia hatnote dab(s) link(s) 
    FlaG["explang"] = "No"    # Denote a Wikipedia hatnote {{Expand language}}
    FlaG["log"] = "No"        # Only 1 log-entry during dab page scans

   # Don't process previously found names
    if( skip_found() ) 
      continue

    if(Debug) {
      printf("____________________________________________________________________________\n")
      printf("%s\n",PG["name"]) 
      printf("¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\n")
    }
      
    if(PG["name"] != "") {

     # Get the initial WP page
      wikipage = wget_str("http://en.wikipedia.org/wiki/" PG["ename"], PG_TEMP PG["ename"])
      if( match(tolower(wikipage),"[Pp]ool queue is full") ) { # Wikipedia Fast-CGI bug. Try again.
        print "Warning: Pool queue is full, trying again: " PG["fullname"] > "/dev/stderr"
        wikipage = wget_str("http://en.wikipedia.org/wiki/" PG["ename"], PG_TEMP PG["ename"])
        if( match(tolower(wikipage),"[Pp]ool queue is full") ) {
          print "Error: Pool queue is full, aborting: " PG["fullname"] > "/dev/stderr"
          continue
        }
      }
      findtype = "via dates"

     # WP will sometimes return nothing if the page is not found, when using command line (different in a browser)
     # Force a Special:Search
      if(wikipage == 0) {          
        if(Debug) 
          print "  ----------------------- search (0) -------------------"
        wikipage = wget_str("http://en.wikipedia.org/wiki/Special:Search/" PG["ename"], PG_TEMP PG["ename"])
        if( match(tolower(wikipage),"[Pp]ool queue is full") ) # Wikipedia Fast-CGI bug. Try again.
          wikipage = wget_str("http://en.wikipedia.org/wiki/Special:Search/" PG["ename"], PG_TEMP PG["ename"])
        findtype = "via search"
      }

      type = wiki_pagetype(wikipage)

     # ..But sometimes returns something if nothing is found
      if(type == "dead" || type == "exact"){         
        if(Debug) 
          print "  ----------------------- search (" type ") -------------------"
        wikipage = wget_str("http://en.wikipedia.org/wiki/Special:Search/" PG["ename"], PG_TEMP PG["ename"])
        if( match(tolower(wikipage),"[Pp]ool queue is full") ) # Wikipedia Fast-CGI bug. Try again.
          wikipage = wget_str("http://en.wikipedia.org/wiki/Special:Search/" PG["ename"], PG_TEMP PG["ename"])
        findtype = "via dead"
        type = "search"
        FlaG["search"] = "Yes"
      }

     # Landed on a search page .. get URL-encoded/decoded names of first search result
      if(type == "search") {
         delete a
         match(wikipage, "mw-search-result-heading\x27><a href=\"[^\"]*\" title=\"[^\"]*\"", a)  # match first hit only. To check them all, replace with patsplit()
           # That is: a quote (\") followed by any number (*) of non-quotes ([^\"]) followed by a quote (\").
         split(a[0],b,"\"") 
         gsub("&#039;","'",b[4])
         split(b[2],d,"/")  

         if(length(d[3]) > 0) { # First article in search results
           if(Debug) 
             print "  ----------------------- search (search) -------------------"
           wikipage = wget_str("http://en.wikipedia.org/wiki/" d[3], PG_TEMP d[3])               
           if( match(tolower(wikipage),"[Pp]ool queue is full") ) # Wikipedia Fast-CGI bug. Try again.
             wikipage = wget_str("http://en.wikipedia.org/wiki/" d[3], PG_TEMP d[3])
           if(wikipage != 0) {
             type = "article"
             PG["ename"] = strip(d[3])
             PG["uname"] = strip(b[4])
             FlaG["search"] = "Yes"
           }
         }
         else {
           if(match(wikipage, "There were no results matching the query")) {
           }
           else {
             type = wiki_pagetype(wikipage)
             if(type == "article" || type == "dab") {  # WP sometimes sends a search directly to an article eg. Raymond MacDonald Alden -> Raymond Macdonald Alden
               match(wikipage,"\"wgTitle\":\"[^,]*,",b)
               split(b[0], d, "\"")
               gsub("&#039;","'",d[4])
               PG["uname"] = d[4]
               PG["ename"] = encode(d[4])
             } else {                 
                 type = "search"
                 a[1] = PG_HOME PG["ename"]
                 print "Error in type=search for: " PG["uname"] ". Saved HTML page with error message to " a[1] > "/dev/stderr"
                 print wikipage > a[1]
                 close(wikipage)
                 mylog(PG_LOG,"Error in type search for: " PG["uname"])
             }
           }
         }
      }

     # Landed on an article.
      if(type == "article") 
        core_logic(PG["uname"], PG["ename"])

     # Landed on a dab page. Run core_logic for each article.
      if(type == "dab") {
        FlaG["dab"] = "Yes"
        if(Debug) {
          print "  ____________main______________"
          print "  " PG["uname"]
          print "  ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯"
        }
        get_dabs(PG["uname"], wikipage)
        ld = length(DaB)
        if(ld > 0) {
          di = 0
          while(di < ld) {
            di++
            if(core_logic(DaB[di]["uname"], DaB[di]["ename"]))
              break
          }
        }
      }

      if(WP["name"] == UNK)
        category_scan()     
      
     # Done looking. Now process and format output -------------------------------------------------------------

     # Count number of books (resource intensive so only when WPname is known)
      if(length(WorkS) == 0 && WP["name"] != UNK) {
        get_books(PG["fullname"])
        numofbooks = length(WorkS) - 1 # Subtract 1 due to WorkS["firstname"]
      } else if(length(WorkS) > 0 && WP["name"] != UNK)
          numofbooks = length(WorkS) - 1
        else
          numofbooks = 0

     # Format date strings
      if(WP["birth"] == UNK) WP["birth"] = ""
      if(WP["birth"] != "" || WP["death"] != "")
        wpdates = WP["birth"] "-" WP["death"]
      else
        wpdates = ""
      if(PG["birth"] == UNK) PG["birth"] = ""
      if(PG["birth"] != "" || PG["death"] != "")
        pgdates = PG["birth"] "-" PG["death"]
      else
        pgdates = ""

     # {{Gutenberg Author}} template status
      if(WP["name"] != UNK) {
        if(WP["template"] == "")  {
          WP["template"] = is_template(WP["name"])
        }
      } 
      else
        WP["template"] = 0

      if(Debug)
        print ""
      
      WP["output"] = sprintf("%s|%s|%s|%s|%s|%s|%s|%s",WP["name"],str[1],PG["fullname"],wpdates,pgdates,numofbooks,WP["template"],WP["findtype"])
      print "<*>  " WP["output"]
      print WP["output"] >> outfile
      close(outfile)
      mylog(PG_LOG, "CLOSE")

      if(!Debug)
        rmfile(PG_TEMP "/*")  

    }
  }
  close(datafile)
}

# Core searching algo - e/uname equates to a legit WP article (not a dab, search, etc..)
#
#
function core_logic(uname, ename      ,article)
{

      if(Debug) 
        print "  ----------------------- CORE: " uname " -------------------"

      article = wget_wiki_source("http://en.wikipedia.org/wiki/Special:Export/" ename, PG_TEMP ename)
      if(length(article) < 10) {                    # safety check
        if(FlaG["redirect"] == "Yes")
          FlaG["redirect"] = "No"
        return 0
      }
      if(FlaG["redirect"] == "Yes") {
        uname = PG["uname"] = Title                 # Re-set working names in case of redirect
        ename = PG["ename"] = encode(Title)
        FlaG["redirect"] = "No"
      }

      if(article ~ "[[[ ]{0,2}Category:[ ]{0,2}"PG["birth"]" births[ ]{0,2}]]"  && article ~ "[[[ ]{0,2}Category:[ ]{0,2}"PG["death"]" deaths[ ]{0,2}]]") {
        if(false_positive(uname) == 0) {
          WP["name"] = uname
          WP["birth"] = PG["birth"]
          WP["death"] = PG["death"]
          WP["findtype"] = "Found: via dates"
          mylog(PG_LOG,"Found: " WP["name"] " : " PG["fullname"] " : via dates")
          return 1
        }
      } else if(length(PG["birth"]) > 0 || length(PG["death"]) > 0) { # Only carry on in certain cases to avoid false positives.
          if(get_date(article, "births") == PG["birth"] || get_date(article, "deaths") == PG["death"]) # For cases where one the dates doesn't match (eg. wrong info, m$
            work_scan(PG["fullname"], uname, article)
          else if(FlaG["fuzzydate"] == "Yes")                  # For cases where PG dates are "fuzzy" (eg. 1901?-2000)
            work_scan(PG["fullname"], uname, article)
          else if( tolower(uname) == tolower(PG["name"]) )
            work_scan(PG["fullname"], uname, article)
      } else {
          work_scan(PG["fullname"], uname, article)
        }

      if(WP["name"] == UNK && FlaG["hatnote"] == "No") {
        if(length(PG["birth"]) > 0 && length(PG["death"]) > 0) {
          if(article ~ PG["birth"] && article ~ PG["death"] && FlaG["dab"] == "No" && FlaG["search"] == "No" ) {
            work_scan(PG["fullname"], uname, article)
            if(WP["name"] == UNK) 
              log_possible("3", uname)
          } 
        } 
      } 

      if(WP["name"] == UNK && FlaG["hatnote"] == "Yes" && FlaG["dab"] == "No" ) {
        if(traverse_hatnotes(uname,ename))
          return 1
      }

      if(WP["name"] == UNK && FlaG["explang"] == "No")
        if(expand_language_template(uname, ename, article))
          return 1

    # If still no match but it has a Gutenberg author template.. 
      if(WP["name"] == UNK && is_template(uname) == 1) {  
  #      if(walk_foreign_articles(uname, ename, article))
  #        return 1
  #      else 
          log_possible("5", uname)
      }
    
      if(WP["name"] != UNK)
        return 1      
      else
        return 0
}


# category_scan
# Purpose: See if the first and last name of base PG name exists in both a birth and death category
# Return: If match, set as Possible 10
#
function category_scan(		z,h,c,d,e,f,g,i,j,cat)
{

  e = j = 0

  z = split(PG["name"],h," ")

  if( length(PG["birth"]) > 0 && length(PG["death"]) > 0) {
    if(Debug) 
      print "  ----------------------- category scan : " PG["name"] " -------------------"
    cat = wget_category("http://tools.wmflabs.org/ext-lnk-discover/sc/sc.php?category=" PG["birth"] "+births", PG_TEMP encode(PG["name"]) "." PG["birth"])
    if(cat ~ h[z]) {
      c = split(cat,d,"<br>")
      i = 1
      while(i <= c) {
        split(d[i],k,"(")
        g = split(k[1],f," ")
        if(f[g] == h[z] && f[1] == h[1]) {
          e++
          arrbirth[e] = d[i]
        }
        i++
      }
    }
  }
  if( length(PG["death"]) > 0 && e > 0 ) {
    cat = wget_category("http://tools.wmflabs.org/ext-lnk-discover/sc/sc.php?category=" PG["death"] "+deaths", PG_TEMP encode(PG["name"]) "." PG["death"])
    if(cat ~ h[z]) {
      c = split(cat,d,"<br>")
      i = 1
      while(i <= c) {
        split(d[i],k,"(")
        g = split(k[1],f," ")
        if(f[g] == h[z] && f[1] == h[1]) {
          j++
          arrdeath[j] = d[i]
        }
        i++
      }
    }
  }

  g = 0

  if(e > 0 && j > 0) {
    i = c = 1
    while(i <= e) {
      while(c <= j) {
        if(arrbirth[i] == arrdeath[c]) {
          g++
          arrmatch[g] = arrbirth[i]
        }
        c++
      }
      i++
    }
  }
  if(g > 0) {
    i = 0
    while(i < g) {
      i++
      log_possible("10", arrmatch[i])
    }
    return 0
  }

}

# Search the foreign-language version(s) of an article for the book title using agrep (aproximate match)
#
# NOTE: No longer used due to lack of effectivness. In 20,000+ names only made 1 verifiable match. 
#
function walk_foreign_articles(uname, ename, article	,json,a,b,bi,c,d,di,e,f,i,j,k,l,p,subarticle,title,titlealt,wmatch,url,filename,command)
{

    if(Debug) 
      print "  ----------------------- walking foreign articles : " uname " -------------------"

   # Populate array linkS[] with interwiki language links
    json = wiki_api_parse(ename, "langlinks")
    c = split(json, a, "[")
    while(i < c) {
      i++
      if(a[i] ~ /\"parse\",\"langlinks\",.?+,\"url\"\]/) {
        j++
        split(a[i],b,"\"")
        split(b[8],d,"/")
        linkS[j]["ename"] = d[5]
        split(d[3],e,"[.]")
        linkS[j]["lang"] = e[1]

      }
      if(a[i] ~ /\"langlinks\",.?+,\"\*\"\]/) {
        split(a[i],b,"\"")
        gsub("&#039;","'",b[8])
        linkS[j]["uname"] = b[8]
      }
    }

    i = 0
    while(i < j) {
      i++

      url = "http://" linkS[i]["lang"] ".wikipedia.org/wiki/Special:Export/" linkS[i]["ename"]
      filename = trimfile(PG_TEMP linkS[i]["ename"] "." linkS[i]["lang"]) 

      wget_file(url, filename)
      subarticle = readfile(filename ".exp")
      StatS["Special:Export"]++

      if(length(WorkS) == 0)
        p = get_books(PG["fullname"])
      else 
        p = length(WorkS) - 1 

      k = wmatch = 0
      while (k < p) {
        k++
        title = tolower(WorkS[k])
        if( agrep(subarticle, title, ".25") ) {
          wmatch++
        }
      }
      if(wmatch > 0) {
       # Sanity check in case of Special:Search or Dab subpage.. is the last name in the article title? Or does art have {{Gutenberg author}}?

        split(tolower(linkS[i]["uname"]), d, "(")             # Remove dab ()
        split(d[1], f, ",")                       # Remove royalty eg. Sir Arthur Heywood, 3rd Baronet
        split(f[1], d, "([ ]of[ ]|[ ]de[ ])" )    # Remove "of" eg. Peire Raimon de Tolosa
        c = split(strip(d[1]),e," ")              # Last name
        e[c] = strip(e[c])
        if( agrep(tolower(PG["name"]), e[c], ".20") && FlaG["dab"] == "No" ) {

          wmatch = 0
          bi = get_date(subarticle, "births")
          di = get_date(subarticle, "deaths")
          if( verify_date(bi) != 0 && verify_date(PG["birth"]) != 0 && int(diffyr(bi, PG["birth"])) > 10 )  # Sanity check: birth or death years are too far apart to be a mistake
            wmatch++
          if( verify_date(di) != 0 && verify_date(PG["death"]) != 0 && int(diffyr(di, PG["death"])) > 10 ) 
            wmatch++

          if(wmatch > 0) {
            if( false_positive(linkS[i]["uname"]) == 0) {  
              WP["name"] = linkS[i]["uname"]    
              WP["birth"] = get_date(article, "births")
              WP["death"] = get_date(article, "deaths")
              mylog(PG_LOG,"Found: " linkS[i]["uname"] " : " PG["fullname"] " : via walk_foreign_articles (" linkS[i]["lang"] ")" )
              WP["findtype"] = "Found: via walk_foreign_articles (" linkS[i]["lang"] ")"
              return 1
            }
          }
          else 
            log_possible("4", linkS[i]["uname"])
        } 
      }
      #sleep(PG_SLEEP_SHORT)
    }
    return 0


}

# If article has {{Expand <language>}} template(s), check the foreign language article, which has more/better info
#
function expand_language_template(uname, ename, article		,i,a,b,c,d,e,j,url,subarticle,p,k,wmatch,title,titlealt,json)
{


    json = wiki_api_parse(ename, "templates")
    if(json ~ "Template:Expand language") {

        FlaG["explang"] = "Yes"

        if(Debug) 
          print "  ----------------------- expand_language_template: " uname " -------------------"

        subarticle = wget_str("http://en.wikipedia.org/wiki/" ename, PG_TEMP ename)
        c = patsplit(subarticle,a, "title=\"[^\"]*\">corresponding article<")

        while(i < c) {
          i++
          split(a[i],d,"\"")
          split(d[2],e,":")
          e[1] = strip(e[1])
          e[2] = encode(strip(e[2]))          

          url = "http://" e[1] ".wikipedia.org/wiki/" e[2]
          filename = trimfile(PG_TEMP e[2] "." e[1]) 

          wget_file(url, filename)
          StatS["Article"]++
          subarticle = readfile(filename ".art")

          if(length(WorkS) == 0) 
            p = get_books(PG["fullname"])
          else
            p = length(WorkS) - 1

          k = wmatch = 0 
          while (k < p) {
            title = tolower(WorkS[k + 1])
            if( agrep(subarticle, title, ".25") ) {
              wmatch++
            }
            k++
          }
          if(wmatch > 0) {
            j = split(tolower(uname),d," ") 
            if( agrep(PG["name"], d[j], ".20")) {
              if( false_positive(uname) == 0) {
                WP["name"] = uname    
                WP["birth"] = get_date(article, "births")
                WP["death"] = get_date(article, "deaths")
                WP["findtype"] = "Found: via expand_language_template (" e[1] ")"
                mylog(PG_LOG,"Found: " uname " : " PG["fullname"] " : via expand_language_template") 
                return 1
              }
            }
          }
          #sleep(PG_SLEEP_SHORT)
        }
    }
    FlaG["explang"] = "No"
    return 0
}

# Traverse and search hatnote pages, including all articles in a hatnoted dab page
#
function traverse_hatnotes(uname, ename		,c,a,i,d,e,pse,psu,psef,psuf,k,j,hatnoteS,ld,di)
{

  FlaG["hatnote"] = "Stop"  # ..stop recursive 

  if(Debug) 
    print "  ----------------------- traverse_hatnotes: " uname " -------------------"

  article = wget_str("http://en.wikipedia.org/wiki/" ename, PG_TEMP ename)

 # Create an array hatnoteS[] containing the hatnoted article names (uname and ename each)
  c = split(article,a,"(<div|</div>)")
  if(c){
    i = 1
    while(i < c) {
      if( match(a[i],"hatnote") && !match(a[i],"mainarticle") ) { # Skip {{main article}} templates.. any others?
        d = patsplit(a[i],pse,"/wiki/[^\"]*\"")
        patsplit(a[i],psu,"title=\"[^\"]*\"")
        j = 1
        while(j <= d) {
          split(pse[j],psef,"(/|\")")
          split(psu[j],psuf,"\"")
          k++
          j++
          if(match(psef[3],"[#]"))
            psef[3] = substr(psef[3],0,RSTART - 1) 
          if(match(psuf[2],"[#]"))
            psuf[2] = substr(psuf[2],0,RSTART - 1) 
          hatnoteS[k]["ename"] = strip(psef[3])
          match(psuf[2],"[#]")
          gsub("&#039;","'",psuf[2])
          hatnoteS[k]["uname"] = strip(psuf[2])
        }
        j = 1
      }
      i++
    }
  }

  if(length(hatnoteS)) {
    i = 1

    while(i <= length(hatnoteS)) {

      subarticle = wget_str("http://en.wikipedia.org/wiki/" hatnoteS[i]["ename"], PG_TEMP hatnoteS[i]["ename"])

     # For hatnoted dab pages
      if(wiki_pagetype(subarticle) == "dab") {
        FlaG["dab"] = "Yes"
        if(Debug) {
          print "  ______________________________"
          print "  " hatnoteS[i]["uname"]
          print "  ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯"
        }
        get_dabs(hatnoteS[i]["uname"], subarticle)
        ld = length(DaB)
        if(ld > 0) {
          di = 1
          while(di <= ld) {
            #sleep(PG_SLEEP_SHORT) # A long dab page could rapid-fire WP
            if(core_logic(DaB[di]["uname"], DaB[di]["ename"])) {
              return 1
            }
            di++
          }
        }
      }

     # For non-dab hatnoted pages
      else {

        if(Debug) 
          print "  ----------------------- following hatnote " uname " -> " hatnoteS[i]["uname"] " -------------------"
        if(core_logic(hatnoteS[i]["uname"], hatnoteS[i]["ename"])) {
          return 1
        }
      }
      i++
    }
  }

  return 0

}

# work_scan - Given a WP article, will scan for book titles that match any in the Gutenberg database
#             for the given author (gbname).
#
#
function work_scan(gbname, pguname, article		,wmatch,j,k,b,d,pname,olurl,olfilename,str,a,c,s,m,l,n,p,f,findtype)
{

  if(Debug) 
    print "  ----------------------- work scan: " pguname " -------------------"

 #Populate WorkS[] with book titles. p is number of books.
  p = get_books(gbname)
  if(p == 0) 
    return 0
  
  wmatch = 0
  
  if(wmatch == 0) { # Search Open Library book-search page - use first book in WorkS[]

    pname = WorkS[1]
   # PG truncates titles at 50-char .. OL search won't work if truncated mid-word so remove truncated last word.
    if(length(pname) == 50){ 
      c = split(pname,b," ")
      pname = ""
      m = 1
      while(m < c) {
        pname = pname " " b[m]
        m++
      }
      #gsub(/^[ ]/,"",pname)
      WorkS[1] = strip(pname)
    }

   # This is HTML scraping. For an API (JSON) method see https://openlibrary.org/dev/docs/api/search
    olurl = "https://openlibrary.org/search?q=" encode_ol(pname)
    olfilename = PG_TEMP encode_ol(pname)
    str = tolower( wget_ssl(olurl, olfilename) )
    if(length(str) < 1500) {              # Aproximate size of HTML headers-only. OL timed out, blocked etc.
      print "Warning: Open Library not responding, trying again: " gbname > "/dev/stderr"
      rmfile(olfilename ".ol")
      sleep(60)
      StatS["OL timeout"]++
      str = tolower(wget_ssl(olurl, olfilename) )
      if(length(str) < 1500) {
        print "Warning: Open Library not responding, trying again: " gbname > "/dev/stderr"
        rmfile(olfilename ".ol")
        sleep(60)
        StatS["OL timeout"]++
        str = tolower(wget_ssl(olurl, olfilename) )
        if(length(str) < 1500) {
          print "Error: Open Library timed out: " gbname > "/dev/stderr"
          mylog(PG_LOG,"Error: Open Library timed out: " gbname)
          WP["findtype"] = "Error: Open Library timed out: " gbname 
          return 0
        }
      }
    }
    gsub("&#39;","'",str) # Open Library HTML encodes the ' character.

    split(pguname,a,/[ ]\(/) # remove dab () eg "John Smith (blacksmith)"
    k = get_name_variants(a[1])

   # Create lastname search pattern eg. "Gibbs<" and ">Gibbs" 
    c = split(tolower(pguname),b," ")
    if(c > 0) {
      dtrail = b[c] "<"
      dhead  = ">" b[c]
    }
    else {
      dtrail = tolower(author) "<"
      dhead = ">" tolower(author)
    }

    c = split(str, b, "<!-- results -->|<span class=\"details\">|<!-- facets -->")    

    m = 1
    while(m < c) {
      if(m != 1) {
        while(n < k) {                                            # Full-name w/ variants + title
          n++
          if(FlaG["dab"] == "Yes") {
            if(b[m] ~ tolower(regesc(WorkS[1])) && b[m] ~ ">"tolower(regesc(VarianT[n]))"<" ) 
              wmatch++
          } else  {
            # agrep is very slow.. skip if in a dab page search
            if( agrep(b[m],WorkS[1],".20") && b[m] ~ ">"tolower(regesc(VarianT[n]))"<" ) {

              wmatch++

   #            print "Found Full-name w/ variants + title: " VarianT[n]
   #            print b[m]  

            }
          }
        }
        n = 0

        match(b[m],"href=\"/authors/[[:alnum:]]+?/[^<]*<",a)       # Lastname + title + first letter of first name 
        split(a[0],d,"\"")
        if(match(d[5],", ")) { # Not perfect solution, catches any name with a comma presumes eg "Smith, John" (last, first) and not outliers "St. Mary, Duke of Luke"
          l = substr(substr(d[5],RSTART+2,length(d[5]) - RLENGTH),1,1)
          j = dhead
        }
        else {
           match(b[m],"href=\"/authors/[[:alnum:]]+?/[^>]*>.")
           l = tolower(substr(b[m],RSTART+RLENGTH-1,1))
           j = dtrail
        }
        s = tolower(substr(pguname,1,1))
        if(s == l && b[m] ~ tolower(WorkS[1]) && b[m] ~ j) {      # Agrep here creates false positives
          if(FlaG["search"] == "No" && FlaG["dab"] == "No")
            wmatch++
          else {
              if(false_positive(pguname) == pguname) {
              }
              else {
                if(no_possibles(PG["fullname"],pguname)) {
                  findtype = "Possible Type 1: " pguname
                }
              }
          }
        }
      }
      m++
    }

    if(Debug)
      print "Books matched (open lib) = " wmatch
    
    if(wmatch > 0) {
      if(sanitycheck(article, pguname, wmatch, "OpenL"))
        return 1
      wmatch = 0
    }    
  }

 # Search Wikipedia article for book title.
 # False positives may arise here if the book title is short or simple phrase
  if(wmatch == 0) {
    k = 0 # Search Wikipedia author-page by book title
    while (k < p) {
      k++
      title = tolower(WorkS[k])
      if( agrep(article,title,".25") ) {
        wmatch++
      }
    }

    if(Debug)
      print "Books matched (wp article) = " wmatch

    if(wmatch > 0) {
      if(sanitycheck(article, pguname, wmatch, "WP"))
        return 1
      wmatch = 0
    } 
  }


 # Search for any Gutenberg URL and mark as Possible
  if(is_gutenberg_etext(pguname) ) 
    log_possible("9", pguname)


 # Search for {{Gutenberg author}} template in article and match if true under certain probable conditions.
  if(wmatch == 0 && FlaG["search"] == "No" && FlaG["dab"] == "No")  {                    
    if(is_template(pguname) == 0) {
 #     if(walk_foreign_articles(pguname, encode(pguname), article))
 #       return 1
 #     else {
        log_possible("2", pguname)
        return 0
 #     }
    }
    else 
      return process_workscan(article, wmatch, 1, pguname, "via template")
  }

  if(findtype ~ "Possible Type 1") { 
   if(false_positive(pguname) == pguname) {
   }
   else {
     if(no_possibles(PG["fullname"],pguname)) {
       if(FlaG["log"] == "No") {
         WP["findtype"] = findtype
         FlaG["log"] = "Yes"
        }
        else
          WP["findtype"] = "Possibles: Multiple matches see log file"

       mylog(PG_LOG,"Possible Type 1: " PG["fullname"] " = " pguname " = " firstfull(PG["fullname"]) )
     }
     else
      findtype = ""
   }
  }
  return 0

}
function process_workscan(article, wmatch, k, uname, msg		,b,d)
{

        if(match(article,"Category:[ ]{0,2}[Ll]iving people")) {
          log_possible("8", uname)
          return 0
        }

        b = get_date(article, "births")
        d = get_date(article, "deaths")

        if( b == "" && d == "" && (FlaG["search"] == "Yes" || FlaG["dab"] == "Yes" || FlaG["hatnote"] == "Stop" )) { 
          return 0
        }

        if( b == "" && d == "" && verify_date(PG["birth"]) == 0 && verify_date(PG["death"]) == 0) {
          log_possible("6", uname)
          return 0
        }

        if( b == "" && d == "" && (verify_date(PG["birth"]) != 0 || verify_date(PG["death"]) != 0) ) {
          log_possible("7", uname)
          return 0
        }

        if( verify_date(b) != 0 && verify_date(PG["birth"]) != 0 && int(diffyr(b, PG["birth"])) > 10 ) { # Sanity check: birth or death years are too far apart to be a mistake
          return 0
        }
        if( verify_date(d) != 0 && verify_date(PG["death"]) != 0 && int(diffyr(d, PG["death"])) > 10 ) {
          return 0
        }

        # If PG birth/death are blank, mark as "Found" and sort it out later via False Positive process. More likely than not it is accurate (?)

        else {
          if( false_positive(uname) == 0) {
            if(k != 0) 
              WP["birth"] = b
            if(k != 0) 
              WP["death"] = d

            mylog(PG_LOG,"Found: " uname " : " PG["fullname"] " : " msg)
            WP["name"] = uname    
            WP["findtype"] = "Found: " msg 
            return wmatch
          }
        }

        return 0
}

# Sanitycheck
#
#
function sanitycheck(article, pguname, wmatch, msg	,h,g,d,f,e,c,i)
{
      split(tolower(pguname), d, "(")           # Remove dab ()
      split(d[1], f, ",")                       # Remove royalty eg. Sir Arthur Heywood, 3rd Baronet
      split(f[1], d, "([ ]of[ ]|[ ]de[ ])" )    # Remove "of" eg. Peire Raimon de Tolosa
      c = split(strip(d[1]),e," ")              # Last name pguname
      e[c] = strip(e[c])
 
      h = split(tolower(PG["name"]), g, " ")    # Last name PG["name"]
      g[h] = strip(g[h])
      
      if( agrep(tolower(PG["name"]), e[c], ".20") && FlaG["dab"] == "No" ) {
        return process_workscan(article, wmatch, 1, pguname, "via work_scan " msg)
      } else if( g[h] == e[c] && FlaG["dab"] == "Yes" ) {
          return process_workscan(article, wmatch, 1, pguname, "via work_scan " msg)
      } else {
          c = get_whatlinkshere(pguname) # Check name against "What links here" list in case of aliases
          i = 0
          while(i < c) {
            i++
            if( agrep(WlH[i]["uname"], PG["name"], ".25") && FlaG["dab"] == "No" ) 
              return process_workscan(article, wmatch, 1, pguname, "via work_scan OpenL WLH") 
          }
      }
      return 0
}



# Regex escapes. Change "Dr." to "Dr[.]"
#
function regesc(var)
{
  gsub("[[]","[[]",var)
  #gsub("[]]","[]]",var) #don't 
  gsub("[.]","[.]",var)
  gsub("[?]","[?]",var)
  gsub("[*]","[*]",var)
  gsub("[(]","[(]",var)
  gsub("[)]","[)]",var)
  gsub("[$]","[$]",var)
  gsub("[|]","[|]",var)
  gsub("[+]","[+]",var)

  return var
}

# Return possible name variants
#
function get_name_variants(uname	,a,c)
{

  delete VarianT

  c = split(uname,a," ")
  if(c <= 1 || c > 4) {
    VarianT[1] = uname
    return 1
  }  
  if(c == 2) { # "John Smith"
    VarianT[1] = a[1] " " a[2]            # "John Smith"
    VarianT[2] = fstlet(a[1]) " " a[2]    # "J. Smith"
    return 2
  }
  if(c == 3) { # "Stephen Tag Day"
    VarianT[1] = a[1] " " a[2] " " a[3]                   # "Stephen Tag Day"
    VarianT[2] = fstlet(a[1]) " " a[2] " " a[3]           # "S. Tag Day"
    VarianT[3] = fstlet(a[1]) " " fstlet(a[2]) " " a[3]   # "S. T. Day"
    VarianT[4] = a[1] " " fstlet(a[2]) " " a[3]           # "Stephen T. Day"
    return 4
  }
 
  if(c == 4) # "Joe Dave Bill IV"
  {
    VarianT[1] = a[1] " " a[2] " " a[3] " " a[4]                         # "Joe Dave Bill IV"
    VarianT[2] = fstlet(a[1]) " " fstlet(a[2]) " " fstlet(a[3]) " " a[4] # "J. D. B. IV"
    VarianT[3] = a[1] " " fstlet(a[2]) " " fstlet(a[3]) " " a[4]         # "Joe D. B. IV"
    VarianT[4] = a[1] " " a[2] " " fstlet(a[3]) " " a[4]                 # "Joe Dave B. IV"
    VarianT[5] = fstlet(a[1]) " " a[2] " " fstlet(a[3]) " " a[4]         # "J. Dave B. IV"
    VarianT[6] = fstlet(a[1]) " " a[2] " " a[3] " " a[4]                 # "J. Dave Bill IV"
    Variant[7] = fstlet(a[1]) " " fstlet(a[2]) " " a[3] " " a[4]         # "J. D. Bill IV"
    return 7
  }

}
function fstlet(str) { return substr(str,1,1) "." }


# Populate WorkS[] with books by author from catalog.rdf
#
# Trim title to essence to allow for matches on Wikipedia/OpenLibrary more likely
#
# Return number of books.
# 
# Also store the full (un-trimmed) title of the first book in WorkS["firstfull"]
#
function get_books(gbname	,s,j,datafile,rawstr,tit,h,d,e,w,name1,name2,i,c,k,l,f,p,o,creatorsingle,creatormulti,contributor)
{

  delete WorkS

  OLD_RS = RS

  RS=("<pgterms:etext|</pgterms:etext>")
  #gsub(/\.|\(|\)|\?|\*/,"\\\\&", gbname) replaced with regesc()

 #Search strings
  creatorsingle = sprintf(">%s</dc:creator", gbname)
  creatormulti = sprintf("<rdf:li rdf:parseType=\"Literal\">%s",gbname)
  contributor = sprintf("<dc:contributor rdf:parseType=\"Literal\">%s",gbname)

  datafile = PG_HOME "catalog.rdf"

  while ((getline rawstr < datafile ) > 0) {

    if(rawstr ~ regesc(creatorsingle) || rawstr ~ regesc(creatormulti) || rawstr ~ regesc(contributor) ) {

      if( match(rawstr, "<pgterms:friendlytitle rdf:parseType=\"Literal\">.*</pgterms:friendlytitle>") ) {

       # Extract title from HTML tags
        tit = strip(substr(rawstr, RSTART+47, RLENGTH-71))

       # Convert any XML codes, or ";"
        gsub(/&gt;/,">",tit)
        gsub(/&quot;/,"\"",tit)
        gsub(/&amp;/,"\\&",tit)
        gsub(";",":",tit)

        if( WorkS["firstfull"] == "")
          WorkS["firstfull"] = tit

       # Rm all the words which follow one of these characters
        split(tit, h, "(—| - |[(]|:)")
        tit = h[1]

       # Rm special cases
        gsub(", in [Ff]our [Pp]arts.*","",tit)
        gsub("in [Ff]our [Pp]arts.*","",tit)
        gsub(", in [Tt]hree [Pp]arts.*","",tit)
        gsub("in [Tt]hree [Pp]arts.*","",tit)
        gsub(", in [Tt]wo [Pp]arts.*","",tit)
        gsub("in [Tt]wo [Pp]arts.*","",tit)
        gsub(/[Mm]lle[.]/, "Mademoiselle",tit)

       # Rm "by name" portion
        split(tit,d,">")
        split(d[2],e,"<")
        split(e[1],w,",")
        name1 = sprintf("by %s",w[1])
        name2 = sprintf("by%s",substr(w[2],0,2))
        split(tit,i,name1"|"name2)
        tit = i[1]

       # Rm words following "." except in certain cases
        l = f = k = 0
        k = split(tit,o," ")
        while(l < k) {
          l++
          if(o[l] ~ /[.]/) {  # Bypass these allowed words
            if(o[l] ~ /Mrs[.]|Mr[.]|[A-Z][.]|Inc[.]|Dr[.]|Capt[.]|doma[.]|St[.]|No[.]/) {
              f++
              p[f] = o[l]
            } else {          # Keep first occurance of non-allowed "word." and drop the remaining words
                f++
                p[f] = o[l]
                p[f] = substr(p[f],0,length(p[f]) - 1) # Rm trailing "."
                break
              }
          } else {
            f++
            p[f] = o[l]
          }
        }
        tit = join(p, 1, length(p), " ")

       # Rm words following "," except if first word (eg. "Sidonia, the Sorceress")
        f = l = k = 0
        delete p
        k = split(tit,o," ")
        while(l < k) {
          l++
          if(o[l] ~ /[,]/) {  # Keep if first word
            if(f == 0) {
              f++
              p[f] = o[l]
            } else {
                f++
                p[f] = o[l]
                p[f] = substr(p[f],0,length(p[f]) - 1) 
                break
            }
          } else {
            f++
            p[f] = o[l]
          }
        }
        tit = join(p, 1, length(p), " ")

       # Rm "English by" and "by [name]"
        if(match(tit,"[.] English by")) {
          c = substr(tit,1,RSTART - 1)
        }
        else 
          c = tit
        if(match(c,PG["name"])) { # Rm "by name" in title (catches some.. need better/additional method)
          if(match(c," by ")) {
            tit = substr(c,1,RSTART-1)
          }
          else
            tit = c
        }
        else
          tit = c

       # Rm last word if "by"
        delete p
        f = 0
        c = split(tit, o, " ")
        if(strip(o[c]) ~ "[Bb]y") {
          while(f < c - 1) {
            f++
            p[f] = o[f]
          }
          tit = join(p, 1, length(p), " ")
        } 

       # Rm second to last word if "by" 
        delete p
        f = 0
        c = split(tit, o, " ")
        if(strip(o[c - 1]) ~ "[Bb]y") {
          while(f < c - 2) {
            f++
            p[f] = o[f]
          }
          tit = join(p, 1, length(p), " ")
        } 

        j++
        WorkS[j] = strip(tit)

      }
    }
  }
  close(datafile)

  RS = OLD_RS

  return j

}
function firstfull(gbname)
{
  if(WorkS["firstfull"] == "")
    get_books(gbname)
  return WorkS["firstfull"]
}


# Populate DaB[] with dab pange entries
#   DaB[x]["ename"] = URL-encoded name
#   DaB[x]["uname"] = Unencoded page name
#
function get_dabs(pguname,dabpage	,jsonin,jsonout,url,command,json,c,i,e,a,b,d,s,f)
{

  delete DaB

 # Get article link names (non-Encoded URL) via MediaWiki API
  json = wiki_api_parse(encode(pguname),"links")
  c = split(json,a,"[")
  i = 1
  e = 1
  while(i <= c) {
    if(match(a[i],"\"[*]\"")) {
      split(a[i],b,"]")
      if(b[2] !~ ":") {
        gsub(/[\\]\"/,"%22",b[2]) #Convert \" 
        split(b[2],d,"\"")
        gsub("&#039;","'",d[2])
        DaB[e]["uname"] = d[2]
        e++
      }
    }
    i++
  }

 # Find the equivilent Encoded URL names in the dab's HTML source
  i = 1
  f = 1
  while(i < e) {
    s = "<a href=\"[^\"]*\" title=\"" DaB[i]["uname"] "\""
    gsub(/\.|\(|\)|\?/,"\\\\&", s)
    if(match(dabpage, s, a)) {
      split(a[0],b,"\"")
      split(b[2],d,"/")
      if(match(d[3],"[#]"))
        d[3] = substr(d[3],0,RSTART - 1) 
      DaB[f]["ename"] = strip(d[3])
      f++
    }
    else {
      DaB[f]["ename"] = encode(DaB[f]["uname"])
      f++
    }
    i++
  }

#  i=0
#  while(i<f) {
#    print DaB[i]["uname"] " = " DaB[i]["ename"]
#    i++
#  }

}

# Populate WLH[] with the "what links here" names (redirects only)
#
function get_whatlinkshere(uname	,json,c,a,i,j)
{

  delete WlH

  if(Debug) 
    print "  ----------------------- whatlinkshere: " uname " -------------------"


  json = wiki_api_backlinks(encode(uname))
  c = split(json, a, "[")
  while(i < c) {
    i++

    if(a[i] ~ /\"query\",\"backlinks\",[0-9]{1,3},\"title\"\]/)  {
      j++
      split(a[i],b,"\"")
      WlH[j]["uname"] = b[8]
      WlH[j]["ename"] = encode(b[8])
    }
  }

  return j

}


# Return the dob or dod from wikisource
#    type = "births" or "deaths"
#
#    BC and AD are removed.
#    20th-century is reformated as 20thC
#    Decade-range returned with trailing "s" eg. "1920s"
#
function get_date(article, type                 ,a,b,s,l)
{

      s = "Category:[ -.,[:alnum:]]*" type

      if(match(article,s,a)) {
        split(a[0],b,":|"type)
        gsub(/BC/,"",b[2])
        gsub(/BCE/,"",b[2])
        gsub(/AD/,"",b[2])
        gsub(/-[Cc]entury/,"C",b[2])
        b[2] = strip(b[2])
        return b[2]
      }
}

# Verify a date is purely numerical ie. "1900", not "16thC"
#
function verify_date(str)
{
  if(str == "")
    return 0
  if(str ~ /[:alpha:]/)
    return 0
  if(str ~ /[:punct:]/)
    return 0

  return 1
}


# Populate vars with PG dates and fuzzydate flag
function get_pg_date(str	,bd)
{

    if(match(str,/Unknown/)) # Old flag from convert.awk nulled
      str = ""

   # PG database sometimes contains dates in form 1995?-2000, which is signal to do deeper searching
    if(match(str,/[?]/)) {       
      FlaG["fuzzydate"] = "Yes"
      gsub(/[?]/,"",str)
    }
    else
      FlaG["fuzzydate"] = "No"

    split(str,bd,"-")
    PG["birth"] = bd[1]       # birth/death dates from catalog.csv
    PG["death"] = bd[2]

   # Set as fuzzy if one date is missing
    if( (PG["birth"] == "" && PG["death"] != "") || (PG["birth"] != "" && PG["death"] == "")  )
      FlaG["fuzzydate"] = "Yes"

}


# Does it have the template? 
#
function is_template(name	,article)
{
  if(Debug) 
    print "  ----------------------- is template: " name " -------------------"

  json = wiki_api_parse(encode(name),"templates")
  if(json ~ "Template:Gutenberg author") 
    return 1
  else {
    article = wget_str("http://en.wikipedia.org/wiki/" encode(name), PG_TEMP encode(name))
    if( match(article,"http://www.gutenberg.org/ebooks/author") )
      return 1
  }
  return 0

}

# Does it have an etext URL?
#
function is_gutenberg_etext(name	,article)
{
  if(Debug) 
    print "  ----------------------- is gutenberg etext: " name " -------------------"

  json = wiki_api_parse(encode(name),"externallinks")
  if(json ~ /www[.]gutenberg[.]org/) 
    return 1
  return 0

}

# Log a possible match
#
function log_possible(number, wpuname	,str,ffp)
{

  if(false_positive(wpuname) == wpuname) {
    return
  }

  if( no_possibles(PG["fullname"],wpuname) ) {
    if(FlaG["log"] == "No") {
      WP["findtype"] = "Possible Type " number ": " wpuname 
      FlaG["log"] = "Yes"
    } else
      WP["findtype"] = "Possibles: Multiple matches see log file"

    str = "Possible Type " number ": " PG["fullname"] " = " wpuname " = " firstfull(PG["fullname"])
    mylog(PG_LOG,str)
  }
}

#Check for existence in match-possible (from old runs of pg2wp)
#
function no_possibles(pgname, wpname	,str,b,wp,pg)
{

  wp = strip(wpname)
  pg = strip(pgname)

  if(Possibles) {
    while ((getline str < Posfilename ) > 0) {
      split(str,b,":")
      if(wp == strip(b[2]) && pg == strip(b[1]) ) {
        close(Posfilename)
        return 0
      }
    }
  }
  close(Posfilename)
  return 1

}

# Return 1 if match in ~/match-false-positive
function false_positive(wpname		,str,b,c,d,i)
{

  if(FalsePositives) {
    while ((getline str < Fpfilename ) > 0) {
      split(str,b,":")
      c = split(b[2],d,";") # For multiple false postivies, separated by a " ; " in the .dat file. See example "Bull, Thomas"
      if(c == 0) {
        if(wpname == strip(b[2]) && PG["fullname"] == strip(b[1]) ) {   
          close(Fpfilename)
          return strip(b[2])
        }
      }
      if(c > 0) {
        i = 0
        while(i < c) {
          i++
          if(wpname == strip(d[i]) && PG["fullname"] == strip(b[1]) ) {
            close(Fpfilename)
            return strip(d[i])
          }
        }
      }
    }
    close(Fpfilename)
  }
  return 0

}

function skip_found(       str,b)
{
  if(Found) {
    while ((getline str < Foundfilename ) > 0) {
      split(str,b,":")
      if( PG["fullname"] == strip(b[1]) ) {
        close(Foundfilename)
        return 1
      }
    }
    close(Foundfilename)
  }
  return 0
}

function wiki_pagetype(page)
{

  if(match(page, "/wiki/Help:Disambiguation")) 
    return "dab"
  if(match(page, "This page or section lists people with the") )
    return "dab"
  if(match(page, "This page or section lists people that share the same") )
    return "dab"
  if(match(page, "There were no results matching the query"))
    return "dead"
  if(match(page, "consider checking the search results below"))
    return "search"
  if(match(page, "Wikipedia does not have an article with this exact name"))
    return "exact"
  return "article" # Might not actually be but shouldn't matter? Check it anyway.

}

# Convert " " to "_" for Wikipedia. 
#
function encode(str)
{

  gsub("&#039;","%27",str) # Sometimes this shows up in otherwise clear text
  gsub(" ","_",str)
  gsub("&","%26",str) 
  gsub("`","%60",str)
  gsub("/", "%2F",str)

  # See notes below before adding more encodes

  return str
}

# Convert " " to "+" for Open Library (HTML 5)
#   Used for book titles
function encode_ol(str)
{

  gsub(" ","+",str)    # These mung the remote site
  gsub("[&]", "%26",str) 
  gsub("[$]", "%24",str) 

  gsub("\"","%22",str) # These probably mung the system(wget) call via sh 
  gsub("`", "%60",str)
  gsub("/", "%2F",str)

  # Note: adding escapes that are not needed will break the search functionality of OL
  # A universal urlencode function is not a good idea.

  return str
}


function stats(total)
{

  print ""
  print "_______________________________________" >> PG_STATS
  print datafile " " Stamp >> PG_STATS
  print "¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯" >> PG_STATS

  print "WP Article     : " StatS["Article"] >> PG_STATS
  print "Special:Search : " StatS["Special:Search"] >> PG_STATS
  print "Special:Export : " StatS["Special:Export"] >> PG_STATS
  print "API template   : " StatS["API template"] >> PG_STATS
  print "API langlinks  : " StatS["API langlinks"] >> PG_STATS
  print "API links      : " StatS["API links"] >> PG_STATS
  print "API extlinks   : " StatS["API externallinks"] >> PG_STATS
  print "API backlinks  : " StatS["API backlinks"] >> PG_STATS
  print "Category Scan  : " StatS["Category Scan"] >> PG_STATS
  print "Open Library   : " StatS["Open Library"] >> PG_STATS
  print "API Timeouts   : " StatS["API timeout"] >> PG_STATS
  print "OL Timeouts    : " StatS["OL timeout"] >> PG_STATS

  total = StatS["Special:Search"] + StatS["Special:Export"] + StatS["Open Library"] + StatS["Category Scan"] + StatS["API template"] + StatS["API langlinks"] + StatS["API links"] + StatS["Article"]

  print "" >> PG_STATS
  print "Total          : " total >> PG_STATS

}


# Difference between two years (strip plus or minus)
# 
function diffyr(y1, y2   ,d)
{

  if(y1 == 0 || y2 == 0)
    return 0

  d = y1 - y2
  if(match(d,"-")) {
    return substr(d,2,length(d))
  }
  else
    return d
}


function usage()
{
  print ""
  print "Usage: pg2wp [OPTION] [PAREMETER]" > "/dev/stderr"
  print "Translate Project Gutenberg author names <-> Wikipedia article names" > "/dev/stderr"
  print ""
  print "Options:"
  print "   -j Filename.auth - a list of PG author names"
  print "   -k Filename.dat  - text deliniated output."
  print "   -z Filename.log  - logging output."
  print ""
  print "Example (3-steps) for first 100 names:"
  print "   1. authors.sh  (create authors.txt from catalog.rdf)"
  print "   2. head -n 100 authors.txt > final.1-100.auth"
  print "   3. pg2wp -k final.1-100.dat -z final.1-100.log -j final.1-100.auth > final.1-100.run"
  print ""
  exit 1
}

