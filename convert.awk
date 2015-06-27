###########################################################################################
# convert.awk (gawk)
#
# Purpose: Convert Project Gutenberg formated name into a field-separated string
#          Database found here: http://www.gutenberg.org/feeds/catalog.rdf.bz2
#
# Output: 
#         Column 1: *Proposed* Wikipedia name, derived from column #3
#         Column 2: DOB-DOD, from column #3
#         Column 3: Raw PG name from catalog.rdf
#
# Copyright (c) User:Green Cardamom (on en.wikipeda.org)
# October 2014
# License: MIT (see LICENSE file included with this package)
###########################################################################################

function convert(str	,ra,rb,c)
{

      c = split(str, A, ",")

## One word
      if(c == 1) {

        leadtrailwhite(1)
        return sprintf("%s|Unknown|%s",cleanstr(A[1],0),str)
      }

## Two words
      if(c == 2) {    
        leadtrailwhite(2)

        if(isadigit(A[2]) == 0) {
          return sprintf("%s%s|Unknown|%s",cleanstr(A[2],2),cleanstr(A[1],0),str)
        } else {
          return sprintf("%s|%s|%s",cleanstr(A[1],0),cleandate(A[2]),str)
        } 
      }

## Three words
      if(c == 3) {
        leadtrailwhite(3)

        if(isde(A[2]) == 1) { # Second word starts with three-letter special ("de " or "da " etc)
          if(isadigit(A[3]) == 0) {
            return sprintf("%s%s%s|Unknown|%s",cleanstr(A[1],2),cleanstr(A[2],2),cleanstr(A[3],0),str)
          } else {
            return sprintf("%s%s|%s|%s",cleanstr(A[1],2),cleanstr(A[2],0),cleandate(A[3]),str)
          }
        } else if(isdq(A[2]) == 1) { # Second word starts with two-letter special ("d'" etc.)
            if(isadigit(A[3]) == 0) {
              return sprintf("%s%s%s|Unknown|%s",cleanstr(A[1],2),cleanstr(A[2],2),cleanstr(A[3],0),str)
            } else {
              return sprintf("%s%s|%s|%s",cleanstr(A[1],2),cleanstr(A[2],0),cleandate(A[3]),str)
            }
        } else if(isadigit(A[3]) == 0) { # Default
            return sprintf("%s%s%s|Unknown|%s",cleanstr(A[3],2),cleanstr(A[2],2),cleanstr(A[1],0),str)
          } else {
            return sprintf("%s%s|%s|%s",cleanstr(A[2],2),cleanstr(A[1],0),cleandate(A[3]),str)
          }
        }

##Four words
      if(c == 4) {
        leadtrailwhite(4)

        if(isde(A[2]) == 1) {
          if(isadigit(A[4]) == 0) {
            return sprintf("%s%s%s%s|Unknown|%s",cleanstr(A[1],2),cleanstr(A[2],2),cleanstr(A[3],2),cleandate(A[4]),str)
          } else {
            return sprintf("%s%s%s|%s|%s",cleanstr(A[1],2),cleanstr(A[2],2),cleanstr(A[3],0),cleandate(A[4]),str)
          }
        } else if(isdq(A[2]) == 1) { # Second word starts with two-letter special ("d'" etc.)
            if(isadigit(A[4]) == 0) {
              return sprintf("%s%s%s%s|Unknown|%s",cleanstr(A[1],2),cleanstr(A[2],2),cleanstr(A[3],2),cleanstr(A[4],0),str)
            } else {
              return sprintf("%s%s%s|%s|%s",cleanstr(A[1],2),cleanstr(A[2],0),cleanstr(A[3],0),cleandate(A[4]),str)
            }
         } else if(isadigit(A[4]) == 0) {
            return sprintf("%s%s%s%s|Unknown|%s",cleanstr(A[4],2),cleanstr(A[3],2),cleanstr(A[2],2),cleanstr(A[1],0),str)
          } else {
            if(isroyalty(A[3]))
              return sprintf("%s|%s|%s",cleanstr(A[2]),cleandate(A[4]),str)
            else
              return sprintf("%s%s%s|%s|%s",cleanstr(A[3],2),cleanstr(A[2],2),cleanstr(A[1],0),cleandate(A[4]),str)
          }
        }

##Five words
      if(c == 5) {
        leadtrailwhite(5)

        if(isadigit(A[5]) == 0) {
          return sprintf("%s%s%s%s%s|Unknown|%s",cleanstr(A[5],2),cleanstr(A[4],2),cleanstr(A[3],2),cleanstr(A[2],2),cleanstr(A[1]),str)
        } else {
          return sprintf("%s%s%s%s|%s|%s",cleanstr(A[4],2),cleanstr(A[3],2),cleanstr(A[2],2),cleanstr(A[1],0),cleandate(A[5]),str)
          }
      }

##Six words
      if(c == 6) {
        leadtrailwhite(6)

        if(isadigit(A[6]) == 0) {
          return sprintf("%s%s%s%s%s%s|Unknown|%s",cleanstr(A[6],2),cleanstr(A[5],2),cleanstr(A[4],2),cleanstr(A[3],2),cleanstr(A[2],2),cleanstr(A[1],2),str)
        } else {
          return sprintf("%s%s%s%s%s|%s|%s",cleanstr(A[5],2),cleanstr(A[4],2),cleanstr(A[3],2),cleanstr(A[2],2),cleanstr(A[1],0),cleandate(A[6]),str)
        }
      }
      if(c > 6) {
        return ""
      }
}

function cleandate(ustr)
{
  gsub(/B[.][ ]{0,2}C[.]/,"", ustr)
  gsub(/B[ ]{0,2}C/,"", ustr)
  gsub(/B[ ]{0,2}C[ ]{0,2}E/,"", ustr)
  gsub("active","",ustr)
  gsub("approximately","",ustr)
  gsub(/ca[.]/,"",ustr)
 #gsub(/[?]/,"",ustr) # Leave this.. evidence dates are fuzzy and do other type of searching
  gsub(" ","",ustr)

  return ustr
}

# ws 1=add leading whitespace) or 2=add trailing whitespace) or 0=none
function cleanstr(ustr,ws)
{
  if(ustr ~ "[(]" ) {
    return unwanted(unpack_parenthesis(ustr),ws)
  } else {
      return unwanted(ustr,ws)
    }
}

function unwanted(ustr,ws)
{

 #XML import cleanup
  gsub(/&gt;/,">",ustr)
  gsub(/&quot;/,"\"",ustr)
  gsub(/&amp;/,"\\&",ustr)

 # Places, things and people to skip or change
  gsub(/^\y1558[-]1603\y/,"",ustr)
  gsub(/^[ ][:]/,"",ustr)
  gsub(/^\y1596[?][-]1678\y/,"",ustr)
  gsub(/^\y1871[-]1929\y/,"",ustr)

  gsub("Γκράτσια Ντελέντα = Grazia Deledda","",ustr)
  gsub("\"A number of the recipes suggest the use of Cottolene.\"--Introduction","",ustr)
  gsub("The tradition that Hanmer wrote the essay had its highly dubious origin in a single unsupported statement by Sir Henry Bunbury","",ustr)
  gsub("made over one hundred years after the work was written....\"","",ustr)
  gsub("\"Bradford Torrey Dodd\" is a fictitious character.","",ustr)
  gsub("Mrs. L. P.","",ustr)
  gsub("100 per cent","",ustr)
  gsub("A Dream Of Red Mansions","",ustr)
  gsub("A Hunting Alphabet","",ustr)
  gsub("A--a","",ustr)
  gsub("ABC du libertaire","",ustr)
  gsub("An abridgement of Garrick's alteration of Midsummer night's dream.","",ustr)
  gsub("Augustan Reprint Society","",ustr)
  gsub("publication number 09","",ustr)
  gsub("Augustan Reprint Society","",ustr)
  gsub("publication number 33","",ustr)
  gsub("Bet Nekhot ha'Alakhot o Toratan shel Rishonim","",ustr)
  gsub("heleq rishon","",ustr)
  gsub("Bryan was a candidate for U.S. President at the time.","",ustr)
  gsub(/^Childhood/,"",ustr)
  gsub("Classic of the Mountains and Seas","",ustr)
  gsub(/^Cottolene at Wikipedia[:] http[:]\/\/en[.]wikipedia[.]org\/wiki\/Cottolene/,"",ustr)
  gsub("Daniels was the wife of the then Secretary of the Navy.","",ustr)
  gsub("Daniels was then the US Secretary of the Navy.","",ustr)
  gsub("Díaz was the president of Mexico.","",ustr)
  gsub("Flow Gently Sweet Afton composed by Spilman; Bonnie","",ustr)
  gsub("Sweet Bessie composed by Gilbert.","",ustr)
  gsub("Frank Ferera and John Paaluhi","",ustr)
  gsub("Hawaiian guitar duet.","",ustr)
  gsub("Friml composed \"Bring Back My Blushing Rose\"; Stamper composed \"Sally","",ustr)
  gsub("Won't You Come Back\".","",ustr)
  gsub("Includes: The Planet Mars","",ustr)
  gsub("by Giovanni Schiaparelli.","",ustr)
  gsub("J. Bisbee on fiddle accompanied by Beulah Bisbee-Schuler on piano.","",ustr)
  gsub("Landfrey was a bugler in the Light Brigade at the Battle of Balaklava","",ustr)
  gsub("October 25","",ustr)
  gsub("1854","",ustr)
  gsub("of the Crimean War.  On this recording Landfrey plays a trumpet that was used at the battle of Waterloo","",ustr)
  gsub("June 18","",ustr)
  gsub("1815","",ustr)
  gsub("of the Napoleonic Wars.","",ustr)
  gsub("Life in a Mediaeval City","",ustr)
  gsub("--ll, --a","",ustr)
  gsub("Minuet composed by Beethoven; Valse by Drigo.","",ustr)
  gsub("Mr. Gladstone was the British Prime Minister at the time.","",ustr)
  gsub("New Zealand. Committee of Inquiry into various aspects of the Problem of Abortion in New Zealand","",ustr)
  gsub("On the Soul","",ustr)
  gsub("One Second of Eternity: An Eastern Novel","",ustr)
  gsub("One-hundred per cent","",ustr)
  gsub("Original Italian first published 1913","",ustr)
  gsub("by Fratelli Treves","",ustr)
  gsub("Milano.","",ustr)
  gsub("Original title was \"Christmas Bells\".","",ustr)
  gsub("Parlow on violin; Falkenstein on piano.","",ustr)
  gsub("Recorded 1919.","",ustr)
  gsub("Recorded Aug 3","",ustr)
  gsub("1908","",ustr)
  gsub("at the Homestead Hotel of Hot Springs","",ustr)
  gsub("Virginia.","",ustr)
  gsub("Recorded August 2","",ustr)
  gsub("1890","",ustr)
  gsub("in London","",ustr)
  gsub("England.","",ustr)
  gsub("Recorded c. 1903.","",ustr)
  gsub("Recorded c. 1914 at the Edison Motion Picture Film Studio","",ustr)
  gsub("Bronx","",ustr)
  gsub("New York.","",ustr)
  gsub("Recorded c. 1916.","",ustr)
  gsub("Recorded c. 1918.","",ustr)
  gsub("Recorded c. 1919.","",ustr)
  gsub("Recorded c. 1920.","",ustr)
  gsub("Recorded c. April 1914.","",ustr)
  gsub("Recorded c. August 1909 in Mexico.","",ustr)
  gsub("Recorded c. October 17","",ustr)
  gsub("1915.","",ustr)
  gsub("Recorded December 18","",ustr)
  gsub("1888","",ustr)
  gsub("in London","",ustr)
  gsub("England.","",ustr)
  gsub("Recorded December 7","",ustr)
  gsub("1912 or February 16","",ustr)
  gsub("1913","",ustr)
  gsub("at the Edison Motion Picture Film Studio","",ustr)
  gsub("Bronx","",ustr)
  gsub("New York.","",ustr)
  gsub("Recorded in December 2001.","",ustr)
  gsub("Recorded in March 2001.","",ustr)
  gsub("Recorded in October of 1919","",ustr)
  gsub("in New York City.","",ustr)
  gsub("Recorded January 1914 at the Edison Motion Picture Film Studio in Bronx","",ustr)
  gsub("Recorded January 20","",ustr)
  gsub("1914 at the Edison Motion Picture Film Studio","",ustr)
  gsub("Recorded July 26","",ustr)
  gsub("1970 at Glenmont (Edison's home)","",ustr)
  gsub("2nd Floor Library","",ustr)
  gsub("West Orange","",ustr)
  gsub("New Jersey.","",ustr)
  gsub("Recorded June 28","",ustr)
  gsub("1921 in New York City.","",ustr)
  gsub("Recorded May 1908 at Bryan's home in Lincoln","",ustr)
  gsub("Nebraska.","",ustr)
  gsub("Recorded November 24","",ustr)
  gsub("1923.","",ustr)
  gsub("Recorded October 10","",ustr)
  gsub("1914.","",ustr)
  gsub("Recorded on September 29","",ustr)
  gsub("1924.","",ustr)
  gsub("Recorded September 12","",ustr)
  gsub("1921.","",ustr)
  gsub("Recorded September 1912.","",ustr)
  gsub("Recorded September 4","",ustr)
  gsub("1925.","",ustr)
  gsub("Saxophone","",ustr)
  gsub("xylophone","",ustr)
  gsub("and piano.","",ustr)
  gsub("Sections 1 and 3 of the essay are omitted in this edition.","",ustr)
  gsub("Selections from \"Wild Animals I Have Known","",ustr)
  gsub("\" #3031.","",ustr)
  gsub("Sequel to: Annals of a quiet neighborhood.","",ustr)
  gsub("Sequel: The Honour of the Clintons","",ustr)
  gsub("See also: #13159.","",ustr)
  gsub("#38647.","",ustr)
  gsub("#31381 Sequel to The Squire's Daughter","",ustr)
  gsub("Sequel: The vicar's daughter.","",ustr)
  gsub("Siegel on mandolin","",ustr)
  gsub("Caveny on ukulele.  Composed by Siegel.","",ustr)
  gsub("Taft was a candidate for U.S. President at the time.","",ustr)
  gsub("The ABC of Drag Hunting","",ustr)
  gsub("The Assemblywomen","",ustr)
  gsub("The banjo is tuned in open D-minor tuning and a 12-string guitar plays melody.","",ustr)
  gsub("'The choice' is by John Pomfret.","",ustr)
  gsub("The Fortune of the Rougons is the first in Zola's Rougon-Macquart series of novels.","",ustr)
  gsub("The Libation Bearers","",ustr)
  gsub("The motion picture element of this sound film is believed lost.","",ustr)
  gsub(/\yThe old Tagalog (Baybayin) font required to read this book can be downloaded from[:] http[:]\/\/www[.]mts[.]net\/[~]pmorrow\/fonts[.]htm/,"",ustr)
  gsub("The sutra of forty-two chapters divulged by the Buddha","",ustr)
  gsub("This is an abridged, school edition.","",ustr)
  gsub("Translation of La fortune des Rougon.","",ustr)
  gsub("Unknown, Unknown","",ustr)
  gsub("Verschenen in drie afleveringen in het tijdschrift \"De Aarde en haar Volken\", jaargang 1886.","",ustr)
  gsub("Vertaald uit het Frans. Oorspronkelijke titel: Voyage aux Philippines et en Malaisie.","",ustr)
  gsub("Wright was an African-American actor educated at Emerson College of Oratory in Boston.  His recitations helped to introduce and popularize the works of African-American poet Dunbar.","",ustr)
  gsub("东京梦华录","",ustr)
  gsub("人间乐","",ustr)
  gsub("分甘餘話","",ustr)
  gsub("幻中遊","",ustr)
  gsub("情变","",ustr)
  gsub("搜神后记","",ustr)
  gsub("无声戏","",ustr)
  gsub("本草备要","",ustr)
  gsub("杜骗新书","",ustr)
  gsub("水调歌头","",ustr)
  gsub("沉淪","",ustr)
  gsub("清代野記","",ustr)
  gsub("瞎骗奇闻","",ustr)
  gsub("筠州黄蘗山斷際禪師傳心法要","",ustr)
  gsub("艷異編","",ustr)
  gsub("菜根谭","",ustr)
  gsub("西厢记","",ustr)
  gsub("西游记","",ustr)
  gsub("负曝闲谈","",ustr)
  gsub("醒世恒言","",ustr)
  gsub("閒情偶寄","",ustr)
  gsub("阿Q正傳","",ustr)
  gsub("風月鑑","",ustr)
  gsub("飮水詞集","",ustr)
  gsub("黃帝宅經","",ustr)
  gsub("黄绣球","",ustr)
  gsub("龙川词","",ustr)

  gsub("On October 21","",ustr)
  gsub("1915 a group of Thomas Edison's friends and business associates played this recording in the library of the Edison Laboratory in West Orange","",ustr)
  gsub("New Jersey and transmitted it to Edison at the Panama-Pacific International Exposition in San Francisco","",ustr)
  gsub("and transmitted it to Edison at the Panama-Pacific International Exposition in San Francisco a group of Thomas Edison's friends and business associates played this recording in the library of the Edison Laboratory in","",ustr)
  gsub("California via the American Telephone and Telegraph Company's newly completed transcontinental telephone line.","",ustr)

 # Name variations
  gsub(/^archaeologist$/,"",ustr)
  gsub(/^\y[Aa][Kk][Aa]\y$/,"",ustr)  
  gsub(/\y[Bb]aron [Dd]e\y/,"",ustr)
  gsub(/\y[Bb]aron\y/,"",ustr)
  gsub(/\y[Bb]arão [Dd]e\y/,"",ustr)
  gsub(/\y[Bb]aroness\y/,"",ustr)
  gsub(/\yBishop of Hippo\y/,"",ustr)
  gsub(/\yBishop of Milan\y/,"",ustr)
  gsub(/\yBishop of Poitiers\y/,"",ustr)
  gsub(/Bp[.]/,"",ustr)
  gsub(/Capt[.]/,"",ustr)
  gsub(/\yCaptain\y/,"",ustr)
  gsub(/\ycomte d[']\y/,"",ustr)
  gsub(/\ycomte de\y/,"",ustr)
  gsub(/^comte Th[.]/,"",ustr)
  gsub(/^comte$/,"",ustr)
  gsub(/\ycomtesse de\y/,"",ustr)
  gsub(/\y[Cc]onde de\y/,"",ustr)
  gsub(/\y[Cc]ondesa de\y/,"",ustr)
  gsub(/\yconsort of Friedrich Margravine Wilhelmine\y/,"",ustr)
  gsub(/Chas[.]/,"",ustr)
  gsub(/Ch[.]/,"",ustr)
  gsub(/Col[.]/,"",ustr)
  gsub(/^Consul$/,"",ustr)
  gsub(/^[Cc]ount$/,"",ustr)
  gsub(/\yduc de\y/,"",ustr)
  gsub(/\yduca degli\y/,"",ustr)
  gsub(/\yduc d'Otrante\y/,"",ustr)
  gsub(/\yduchesse d'\y/,"",ustr)
  gsub(/\y[Dd]uchesse de\y/,"",ustr)
  gsub(/\y[Dd]uke of\y/,"",ustr)
  gsub(/Dr[.]/,"",ustr)
  gsub(/\y[Ee]arl of\y/,"",ustr)
  gsub(/^Earl$/,"",ustr)
  gsub(/\yEmperor of Hindustan\y/,"",ustr)
  gsub(/\yEmperor of Rome\y/,"",ustr)
  gsub(/\yEmperor of the French\y/,"",ustr)
  gsub(/F[.]R[.]G[.]S[.]/,"",ustr)
  gsub(/F[.]R[.]H[.]S[.]/,"",ustr)
  gsub(/F[.]S[.]A[.]/,"",ustr)
  gsub(/F[.]A[.]S[.]/,"",ustr)
  gsub(/^Father$/,"",ustr)
  gsub(/Fr[.]/,"",ustr)
  gsub(/Fr[.]-/,"",ustr)
  gsub(/friherrinna/,"",ustr)
  gsub(/friherre/,"",ustr)
  gsub(/^gardener$/,"",ustr)
  gsub(/Geo[.]/,"George",ustr)
  gsub(/^\y[Gg]raf von\y/,"",ustr)
  gsub(/^[Gg]rafinia/,"",ustr)
  gsub(/^[Gg]raf$/,"",ustr)
  gsub(/\yGrand-Duke of Tuscany\y/,"",ustr)
  gsub(/Herm[.]/,"Herman",ustr)
  gsub(/^hrabia$/,"",ustr)
  gsub(/-H/,"H",ustr)
  gsub(/Jac[.]/,"Jacob",ustr)
  gsub(/jin shi [0-9]{0,4}/,"",ustr)
  gsub(/ju ren [0-9]{0,4}/,"",ustr)
  gsub(/Jr[.]/,"",ustr)
  gsub(/\yKing of Babylonia\y/,"",ustr)
  gsub(/\yKing of England\y/,"",ustr)
  gsub(/\yKing of France consort of Henry IV\y/,"",ustr)
  gsub(/\yKing of Great Britain\y/,"",ustr)
  gsub(/\yKing of Navarre consort of Henry II\y/,"",ustr)
  gsub(/\yKing of Romania consort of Ferdinand I\y/,"",ustr)
  gsub(/\yKing of the Hawaiian Islands\y/,"",ustr)
  gsub(/^kniaz$/,"",ustr)
  gsub(/L[.]-M[.]-G/,"L. M. G.",ustr)
  gsub(/^[Ll]ady$/,"",ustr)
  gsub(/^[Ll]ord$/,"",ustr)
  gsub(/^[Ll]udvig$/,"Ludwig",ustr)
  gsub(/^[Ll]ud[.]/,"",ustr)
  gsub(/\ymarquise de La Rochejaquelein\y/,"",ustr)
  gsub(/\yMarie-Madeleine Pioche de La Vergne La Fayette\y/,"Madame de La Fayette",ustr)
  gsub(/\ymarqués de San Francisco\y/,"",ustr)
  gsub(/^\ymarquis de\y/,"",ustr)
  gsub(/Mme[.][ ]E[.][ ]de[ ]Pressensé/,"Edmond de Pressensé",ustr)
  gsub(/^Mme[.]/,"",ustr)
  gsub(/Mrs[.]/,"",ustr)
  gsub(/Mrs/,"",ustr)
  gsub(/Mr[.]/,"",ustr)
  gsub(/^Mr$/,"",ustr)
  gsub(/N[.]-J[.]/,"N. J.",ustr)
  gsub(/^née$/,"",ustr)
  gsub(/[[][Pp]seud[.][]]/,"",ustr)
  gsub(/[Pp]seud[.]/,"",ustr)
  gsub(/[(][Pp]seudonym[)]/,"",ustr)
  gsub(/[(][Pp]seudonym[.][)]/,"",ustr)
  gsub(/[[][Pp]seudonym[]]/,"",ustr)
  gsub(/[[][Pp]seudonym[.][]]/,"",ustr)
  gsub(/[Pp]seudonym[.]/,"",ustr)
  gsub(/[Pp]seudonym/,"",ustr)
  gsub(/[Pp]seud[.]/,"",ustr)
  gsub(/[Pp]seud/,"",ustr)
  gsub(/[Pp][Hh][.][Dd][.]/,"",ustr)
  gsub(/[Pp][Hh][Dd][.]/,"",ustr)
  gsub(/[Pp][Hh][.][Dd]/,"",ustr)
  gsub(/^Ph[.]/,"",ustr)
  gsub(/^Rev[.]/,"",ustr)
  gsub(/\ySaint of Avila Teresa\y/,"Saint Teresa",ustr)
  gsub(/\ySaint of Clairvaux Bernard\y/,"Bernard of Clairvaux",ustr)
  gsub(/\ySaint of Loyola Ignatius\y/,"Ignatius of Loyola",ustr)
  gsub(/\ySaint of Siena Catherine\y/,"Catherine of Siena",ustr)
  gsub(/\ySaint the Apostle John\y/,"Saint John",ustr)
  gsub(/\ySainte de Lisieux Thérèse\y/,"Thérèse of Lisieux",ustr)
  gsub(/^schoolmaster$/,"",ustr)
  gsub(/^Right Rev[.]/,"",ustr)
  gsub(/^Sir$/,"",ustr)
  gsub(/^swámi$/,"",ustr)
  gsub(/^Th[.]/,"Thérèse",ustr)
  gsub(/\ythe Younger Pliny\y/,"Pliny the Younger",ustr)
  gsub(/^Theo[.]/,"",ustr)
  gsub(/^[Vv]iscountess$/,"",ustr)
  gsub(/^[Vv]icomtesse$/,"",ustr)
  gsub(/^[Vv]iscount$/,"",ustr)
  gsub(/^\y[Vv]icente de\y/,"",ustr)
  gsub(/^\y[Vv]icomte de\y/,"",ustr)
  gsub(/^W[.]-F[.]/,"W. F.",ustr)
  gsub(/^Wm[.]/,"William",ustr)

  # Leading and trailing white remove
  gsub(/^[ \t]+/,"",ustr)
  gsub(/[ \t]+$/,"",ustr)    

  #Add back in leading or trailing (0=none)
  if(length(ustr) > 0) {
    if(ws == 1) 
      return sprintf(" %s",ustr)
    if(ws == 2) 
      return sprintf("%s ",ustr)
    if(ws == 0) 
      return sprintf("%s",ustr)
  }
}

# Change cases of "W. H. (William Hood)" -> "William Hood"
function unpack_parenthesis(ustr)
{
    match(ustr,"[(].*[)]")
    unpacked = substr(ustr,RSTART+1,RLENGTH-2)
   # Special cases
    if ( unpacked ~ /(^\yname unknown\y$|^\ythe Younger\y$|^pseudonym$|^\yAn Englishman\y$|^\yAKA George Bourne\y$|^\ynée Krohn\y$|^\yU[.]S[.]\y$|^\yN[.]Y[.]\y$|^\yaka Rachilde\y$|^\yEdison studio ensemble\y$|^\yPlotinus\y$|^\yCalif[.]\y$)/) {
      return substr(ustr,0,RSTART-2)
    }
    if ( unpacked ~ /^pere$/) {
      return unstr
    }
    return unpacked
}

# Return 1 if first character in str is 0-9 (or "-", "ca.", "active", "approximately")
function isadigit(ustr)
{
  fc = substr(ustr, 0, 1)

  if(fc ~ /[0-9]|[-]/) {
    return 1
  }
  if(ustr ~ /^active/) {
    return 1    
  }
  if(ustr ~ /^approximately/) {
    return 1    
  }
  if(ustr ~ /^ca[.]/) {
    return 1    
  }

  return 0
}

# Return 1 if first word is "de ", "da ", "of "
function isde(ustr)
{
  fc = substr(ustr, 0, 3)
  if(fc == "de " || fc == "da " || fc == "of " ) {
    return 1
  }
  return 0
}

# Return 1 if first word is "d'" or "à "
function isdq(ustr)
{
  fc = substr(ustr, 0, 2)
  if(fc == "d'" || fc == "à ") {
    return 1
  }
  return 0
}

# Remove leading and trailing whitespace from a[]
function leadtrailwhite(num)
{
  i = 0
  while(i < num) {
    i++
    gsub(/^[ \t]+/,"",A[i])
    gsub(/[ \t]+$/,"",A[i])    
  }
  
}

function isroyalty(str)
{
  if(str ~ /[Ee]arl of|[Dd]uke of|[Cc]ountess of|[Mm]arquess of/ )
    return 1
  return 0
}

