#!/bin/awk -f
# Given variable "r" (eg. awk -v r="Smith, John" -f work.awk)
# Return list of work titles from catalog.rdf
#
#
BEGIN {

  r = ARGV[1]

  RS=("<pgterms:etext|</pgterms:etext>")
  gsub(/\.|\(|\)|\?|\*/,"\\\\&", r)

 #Search string
  creatorsingle = sprintf(">%s</dc:creator",r)
  creatormulti = sprintf("<rdf:li rdf:parseType=\"Literal\">%s",r)
  contributor = sprintf("<dc:contributor rdf:parseType=\"Literal\">%s",r)

  while ((getline rawstr < "catalog.rdf" ) > 0) {

    if(rawstr ~ creatorsingle || rawstr ~ creatormulti || rawstr ~ contributor) {

      if( match(rawstr, "<pgterms:friendlytitle rdf:parseType=\"Literal\">.*</pgterms:friendlytitle>") ) {
        
       #Extract title from HTML tags
        tit = substr(rawstr, RSTART+47, RLENGTH-71)
        
       #Convert any XML codes, or ";" 
        gsub(/&gt;/,">",tit)
        gsub(/&quot;/,"\"",tit)
        gsub(/&amp;/,"\\&",tit)
        gsub(";",":",tit)

       #Remove sub-title
#        split(tit,h,":")

       #Remove "by name" portion
        split(s,d,">")
        split(d[2],e,"<")
        split(e[1],w,",")
        name1 = sprintf("by %s",w[1])
        name2 = sprintf("by%s",substr(w[2],0,2))
        split(h[1],i,name1"|"name2)

#        print i[1]
        print rawstr

      }
    }
  }
  close("catalog.rdf")

}
