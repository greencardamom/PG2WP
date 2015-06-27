#################################################################
# PG2WP
# init.awk 
#
# This module defines system-specific paths
#
# Copyright (c) User:Green Cardamom (on en.wikipeda.org)
# October 2014
# License: MIT (see LICENSE file included with this package)
#################################################################

BEGIN{

 # Customize this part to your system

  PG_HOME = "/home/username/pg/"

  API_AGENT = "PG2WP Project Gutenberg to Wikipedia (username@email.com)"

  AWK = "/bin/awk"
  AGREP = "/usr/local/bin/agrep"
  WGET = "/bin/wget"
  MKDIR = "/bin/mkdir"
  RM = "/bin/rm"
  MV = "/bin/mv"

# -------------------------- #

 # Create temp directory

  Stamp = strftime("%Y%m%d%H%M%S")
#  Stamp = "001"


  PG_TEMPDIR = PG_HOME "temp/"
  cwd = ENVIRON["PWD"]
  ret = chdir(PG_TEMPDIR)
  if (ret < 0) {
    mkdir(PG_TEMPDIR)
  }
  chdir(cwd)

  PG_TEMP = PG_TEMPDIR "pg-" Stamp "/"
  mkdir(PG_TEMP)

  PG_STATS = PG_HOME "pg.stats"

  JSON = PG_HOME "JSON.awk"
  PG_LOG = PG_HOME "pg.log"

  PG_SLEEP_SHORT = 1

  UNK = "NA"  
 
}
