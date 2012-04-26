namespace eval headlines {
set ver 0.1.6
#################################################################################################
# Copyright 2012 lee8oi@gmail.com
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# http://www.gnu.org/licenses/
#
#-----------------------------------------------------------------------
# headlines eggdrop script by lee8oi@gmail.com
#
# There's plenty of eggdrop news syndication scripts if you are looking for something automatic. 
# This script is for retrieving news now. Right from the source. The source can be a feed url directly or
# it can be the name of one of the preconfigured feeds. The output is sent to your nick through
# the irc notice system keeping the public channels spam free. The direct approach to handling feeds
# allows the script manage more news sources than your average eggdrop news script. We only get the
# news we ask for, when we ask for it, nothing else.
# 
# This script is currently written for utf-8 patched bots and assumes the users system is utf-8.
# It currenly supports RSS and Atom feeds. Its main job is to retrieve the headlines(titles & links).
# You can specify feed by feed name or use a url and optionally followed by how many headlines
# you would like to see.
#
# Note: Encoding issues are common. If you have problems please make sure your bot is patched for
# utf-8 as outlined here: http://eggwiki.org/Utf-8
# If you still have problems consider updating to the latest tcl8.6 and recompiling your bot. This
# script DOES WORK. Its just hard to fix all the possible encoding issues up front. I'll work in the
# fixes as I go. Check the 'Custom Charsets' section in 'Configuration' for more information about
# setting charsets for specific feeds.
#
# Currently you can call the rss script from any channel the bot resides in or by using /msg or /query. 
# The output is 'noticed' directly to you.
#
# Usage:
#
# Retrieve news:
# !news <feedname-or-url> ?how-many?
#
# List the available feeds
# !feeds
#
#################################################################################################
# Configuration:
#
# Default number of headlines to show when ?how-many? is not specified.
	variable numberOfheadlines  5
#
# Feeds
  set feeds(google) "http://news.google.com/news?ned=us&topic=h&output=rss"
  set feeds(linuxtoday) "http://feeds.feedburner.com/linuxtoday/linux?format=xml"
  set feeds(securitynow) "http://leoville.tv/podcasts/sn.xml"
  set feeds(krotkie) "http://www.joemonster.org/backend.php?channel=krotkie"
  set feeds(bfh-alerts) "http://www.battlefieldheroes.com/en/forum/syndication.php?fid=43&limit=5"
  set feeds(bfh-main) "http://www.battlefieldheroes.com/en/forum/syndication.php?fid=94&type=atom1.0&limit=15"
  set feeds(rususa) "http://www.rususa.com/tools/rss/feed.asp-rss-newsrus"
  set feeds(google-china) "http://news.google.com/news?ned=cn&topic=po&output=rss"
  set feeds(apple-japan) "http://rss.support.apple.com/ja_JP/"
	set feeds(linuxtoday) "http://feeds.feedburner.com/linuxtoday/linux?format=xml"
	set feeds(mageia-group) "http://identi.ca/api/statusnet/groups/timeline/16485.rss"
  
# Custom charsets
#  Usage: set charset(feedname) "charset"
# Use this section to specify the charset for a specific feed to be converted from.
# This will convert the feed to unicode.
#
# **This section currently is only used by japanese based rss feeds listed as 'utf-8'
# if script detects "euc-jp" charset it will skip encoding as well as htmldecoding
# in order to display japanese characters correctly in output.
# For example, to set the charset for the japanese rss feed 'feedname':
# set charset(feedname) "euc-jp"
#
  set charset(japan) "euc-jp"
#
#
# which method should be used when shortening the url?
# 0 --> http://tinyurl.com
# 1 --> http://u.nu
# 2 --> http://is.gd
# 3 --> http://cli.gs
# ---  [ 0 - 5 ]
variable urlShortType 0

# END OF FEED CONFIGURATION
#################################################################################################
}
package require http
if {![catch {package require tls}]} { ::http::register https 443 ::tls::socket }
bind pub - !rss ::headlines::news
bind pub - !atom ::headlines::news
bind pub - !news ::headlines::news
bind pub - !feeds ::headlines::flist
bind msg - !feeds ::headlines::flist
bind msg - !news ::headlines::msg_news
bind pub - !test ::headlines::pub_news
namespace eval headlines {
proc msg_news {nick userhost handle text} {
	::headlines::grabnews $nick $text
}
proc pub_news {nick host user chan text} {
	::headlines::grabnews $nick $text
}

proc flist {nick args} {
	#:get list of feeds available:::::::::::::::::::::::::::::::::::::::::::
	variable feeds; set result ""
	foreach item [array names ::headlines::feeds] {
		append result "$item "
	}
	return $result
}
proc grabnews {target text} {
	set arr [split $text]
	set feed [string tolower [lindex $arr 0]]
	set numb [string tolower [lindex $arr 1]]
	if {[string length $feed] >= 10 && [regexp {^(f|ht)tp(s|)://} $feed] && ![regexp {://([^/:]*:([^/]*@|\d+(/|$))|.*/\.)} $feed]} {
		puthelp "notice $target : Url detected : $feed"
		set url $feed
	} elseif {[info exists ::headlines::feeds($feed)]} {
		set url $::headlines::feeds($feed)
	}
	if (![string is integer -strict $numb]) {
		set numb [set ::headlines::numberOfheadlines]
	}
	set data [::headlines::fetch $feed $url]
	regexp {(?i)<rss.*>(.*?)</rss>} $data rssdata none
	regexp {(?i)<feed.*>(.*?)</feed>} $data atomdata none
	if {[info exists rssdata]} {
		regsub -all {(?i)<items.*?>.*?</items>} $rssdata {} data
		set count 1
		foreach {foo item} [regexp -all -inline {(?i)<item.*?>(.*?)</item>} $data] {
			set item [string map {"<![CDATA[" "" "]]>" ""} $item]
			regexp {<title.*?>(.*?)</title>}  $item subt title
			regexp {<link.*?>(.*?)</link}     $item subl link
			if {![info exists title]} {set title "(none)"} {set title [unhtml [join [split $title]]]}
			if {![info exists link]}  {set link  "(none)"} {set link [unhtml [join [split $link]]]}
			set tinyurl [::headlines::tinyurl $link]
			puthelp "notice $target : $title ($tinyurl)"
			if {($count == $numb)} {
				return
			} else {
				incr count
			}
		}
	} elseif {[info exists atomdata]} {
		set count 1
		foreach {foo item} [regexp -all -inline {(?i)<entry.*?>(.*?)</entry>} $atomdata] {
			set item [string map {"<![CDATA[" "" "]]>" ""} $item]
			regexp {<title.*?>(.*?)</title>}  $item subt title
			regexp {<link.*?href=\"(.*?)\"} $item sub1 link
			if {![info exists title]} {set title "(none)"} {set title [unhtml [join [split $title]]]}
			if {![info exists link]}  {set link  "(none)"} {set link [unhtml [join [split $link]]]}
			set tinyurl [::headlines::tinyurl $link]
			puthelp "notice $target : $feed $title ($tinyurl)"
			if {($count == $numb)} {
				return
			} else {
				incr count
			}
		}
	}
}
proc news {nick host user chan text} {
	set arr [split $text]
	set feed [string tolower [lindex $arr 0]]
	set numb [string tolower [lindex $arr 1]]
	if {[string length $feed] >= 10 && [regexp {^(f|ht)tp(s|)://} $feed] && ![regexp {://([^/:]*:([^/]*@|\d+(/|$))|.*/\.)} $feed]} {
		puthelp "notice $nick : Url detected : $feed"
		set url $feed
	} elseif {[info exists ::headlines::feeds($feed)]} {
		set url $::headlines::feeds($feed)
	} else {
		set result [::headlines::flist $nick]
		set available "Available feeds: $result"
		if {$feed == ""} {
			puthelp "notice $nick : Usage !news <feed-or-url> ?num? ~~ $available"
			return
		} else {
			puthelp "notice $nick : Invalid feed ~~ $available"
			return
		}
	}
	if (![string is integer -strict $numb]) {
		set numb [set ::headlines::numberOfheadlines]
	}
	set data [::headlines::fetch $feed $url]
	regexp {(?i)<rss.*>(.*?)</rss>} $data rssdata none
	regexp {(?i)<feed.*>(.*?)</feed>} $data atomdata none
	if {[info exists rssdata]} {
		regsub -all {(?i)<items.*?>.*?</items>} $rssdata {} data
		set count 1
		foreach {foo item} [regexp -all -inline {(?i)<item.*?>(.*?)</item>} $data] {
			set item [string map {"<![CDATA[" "" "]]>" ""} $item]
			regexp {<title.*?>(.*?)</title>}  $item subt title
			regexp {<link.*?>(.*?)</link}     $item subl link
			if {![info exists title]} {set title "(none)"} {set title [unhtml [join [split $title]]]}
			if {![info exists link]}  {set link  "(none)"} {set link [unhtml [join [split $link]]]}
			puthelp "notice $nick : $title ($link)"
			if {($count == $numb)} {
				return
			} else {
				incr count
			}
		}
	} elseif {[info exists atomdata]} {
		set count 1
		foreach {foo item} [regexp -all -inline {(?i)<entry.*?>(.*?)</entry>} $atomdata] {
			set item [string map {"<![CDATA[" "" "]]>" ""} $item]
			regexp {<title.*?>(.*?)</title>}  $item subt title
			regexp {<link.*?href=\"(.*?)\"} $item sub1 link
			if {![info exists title]} {set title "(none)"} {set title [unhtml [join [split $title]]]}
			if {![info exists link]}  {set link  "(none)"} {set link [unhtml [join [split $link]]]}
			puthelp "notice $nick : $feed $title ($link)"
			if {($count == $numb)} {
				return
			} else {
				incr count
			}
		}
	}
}
proc fetch {feed {url ""}} {
	set ua "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.5) Gecko/2008120122 Firefox/3.0.5"
	set http [::http::config -useragent $ua]
	catch {set http [::http::geturl $url -timeout 60000]} error
	if {[info exists http]} {
		if { [::http::status $http] == "timeout" } {
			return 0
		}
		upvar #0 $http state
		array set meta $state(meta)
		set url $state(url)
		set data [::http::data $http]
		#:handle redirects::::::::::::::::::::::::::::::::::::::::::::::
		foreach {name value} $state(meta) {
			if {[regexp -nocase ^location$ $name]} {
				set mapvar [list " " "%20"]
				::http::cleanup $http
				catch {set http [::http::geturl $value -timeout 60000]} error
				if {![string match -nocase "::http::*" $error]} {
					return "http error: [string totitle $error] \( $value \)"
				}
				if {![string equal -nocase [::http::status $http] "ok"]} {
					return "status: [::http::status $http]"
				}
				set url [string map {" " "%20"} $value]
				upvar #0 $http state
				if {[incr r] > 10} { puthelp "notice $nick : redirect error (>10 too deep) \( $url \)" ; return 0}
				set data [::http::data $http]
				::http::cleanup $http
			}
		}
		# url is now stored in $url variable
		set html $data
		if {[regexp -nocase {"Content-Type" content=".*?; charset=(.*?)".*?>} $html - char]} {
			set char [string trim [string trim $char "\"' /"] {;}]
			regexp {^(.*?)"} $char - char
			set mset $char
			if {![string length $char]} { set char "None Given" ; set char2 "None Given" }
			set char2 [string tolower [string map -nocase {"UTF-" "utf-" "iso-" "iso" "windows-" "cp" "shift_jis" "shiftjis"} $char]]
		} else {
			if {[regexp -nocase {<meta content=".*?; charset=(.*?)".*?>} $html - char]} {
				set char [string trim $char "\"' /"]
				regexp {^(.*?)"} $char - char
				set mset $char
				if {![string length $char]} { set char "None Given" ; set char2 "None Given" }
				set char2 [string tolower [string map -nocase {"UTF-" "utf-" "iso-" "iso" "windows-" "cp" "shift_jis" "shiftjis"} $char]]
			} elseif {[regexp -nocase {encoding="(.*?)"} $html - char]} {
				set mset $char ; set char [string trim $char]
				if {![string length $char]} { set char "None Given" ; set char2 "None Given" }
				set char2 [string tolower [string map -nocase {"UTF-" "utf-" "iso-" "iso" "windows-" "cp" "shift_jis" "shiftjis"} $char]]
			} else {
				set char "None Given" ; set char2 "None Given" ; set mset "None Given"
			}
		}
		set char3 [string tolower [string map -nocase {"UTF-" "utf-" "iso-" "iso" "windows-" "cp" "shift_jis" "shiftjis"} $state(charset)]]
		set char [string trim $char2 {;}]
		if {($char2 == "None Given") && ($char3 != "None Given")} {
			set char $char3
		} else {
			set char $char2
		}
		variable ::headlines::charset
		if {[info exists charset($feed)]} {
			set char $charset($feed)
		}
		switch $char {
			"euc-jp" {
			}
			default {
				if {[string equal -nocase "utf-8" [encoding system]]} {
					set html [encoding convertfrom $char $html]
					set data [htmldecode $html]
				}
			}
		}
		return $data
	}
}
proc unhtml {{data ""}} {
	if {($data == "")} {puts "remove html tags from data. usage: unhtml <data>"; return}
	regsub -all "(?:<b>|</b>|<b />|<em>|</em>|<strong>|</strong>)" $data"\002" data
	regsub -all "(?:<u>|</u>|<u />)" $data "\037" data
	regsub -all "(?:<br>|<br/>|<br />)" $data ". " data
	regsub -all "<script.*?>.*?</script>" $data "" data
	regsub -all "<style.*?>.*?</style>" $data "" data
	regsub -all -- {<.*?>} $data " " data
	while {[string match "*  *" $data]} { regsub -all "  " $data " " data }
	return [string trim $data]
}
proc tinyurl {url} {
   set ua "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.5) Gecko/2008120122 Firefox/3.0.5"
   set http [::http::config -useragent $ua -urlencoding "utf-8"]
   set query "http://tinyurl.com/api-create.php?[http::formatQuery url $url]"
   set token [http::geturl $query -timeout 3000]
   upvar #0 $token state
   if {[string length $state(body)]} { return [string map {"\n" ""} $state(body)] }
		putlog "tiny url set to $url"
   return $url
}
proc htmldecode {{data ""}} {
	if {($data == "")} {puts "remove html markup codes from data. usage: htmldecode <data>"; return}
	if {![string match *&* $data]} {return $data}
	set escapes {
							 &nbsp; \xa0 &iexcl; \xa1 &cent; \xa2 &pound; \xa3 &curren; \xa4
							 &yen; \xa5 &brvbar; \xa6 &sect; \xa7 &uml; \xa8 &copy; \xa9
							 &ordf; \xaa &laquo; \xab &not; \xac &shy; \xad &reg; \xae
							 &macr; \xaf &deg; \xb0 &plusmn; \xb1 &sup2; \xb2 &sup3; \xb3
							 &acute; \xb4 &micro; \xb5 &para; \xb6 &middot; \xb7 &cedil; \xb8
							 &sup1; \xb9 &ordm; \xba &raquo; \xbb &frac14; \xbc &frac12; \xbd
							 &frac34; \xbe &iquest; \xbf &Agrave; \xc0 &Aacute; \xc1 &Acirc; \xc2
							 &Atilde; \xc3 &Auml; \xc4 &Aring; \xc5 &AElig; \xc6 &Ccedil; \xc7
							 &Egrave; \xc8 &Eacute; \xc9 &Ecirc; \xca &Euml; \xcb &Igrave; \xcc
							 &Iacute; \xcd &Icirc; \xce &Iuml; \xcf &ETH; \xd0 &Ntilde; \xd1
							 &Ograve; \xd2 &Oacute; \xd3 &Ocirc; \xd4 &Otilde; \xd5 &Ouml; \xd6
							 &times; \xd7 &Oslash; \xd8 &Ugrave; \xd9 &Uacute; \xda &Ucirc; \xdb
							 &Uuml; \xdc &Yacute; \xdd &THORN; \xde &szlig; \xdf &agrave; \xe0
							 &aacute; \xe1 &acirc; \xe2 &atilde; \xe3 &auml; \xe4 &aring; \xe5
							 &aelig; \xe6 &ccedil; \xe7 &egrave; \xe8 &eacute; \xe9 &ecirc; \xea
							 &euml; \xeb &igrave; \xec &iacute; \xed &icirc; \xee &iuml; \xef
							 &eth; \xf0 &ntilde; \xf1 &ograve; \xf2 &oacute; \xf3 &ocirc; \xf4
							 &otilde; \xf5 &ouml; \xf6 &divide; \xf7 &oslash; \xf8 &ugrave; \xf9
							 &uacute; \xfa &ucirc; \xfb &uuml; \xfc &yacute; \xfd &thorn; \xfe
							 &yuml; \xff &fnof; \u192 &Alpha; \u391 &Beta; \u392 &Gamma; \u393 &Delta; \u394
							 &Epsilon; \u395 &Zeta; \u396 &Eta; \u397 &Theta; \u398 &Iota; \u399
							 &Kappa; \u39A &Lambda; \u39B &Mu; \u39C &Nu; \u39D &Xi; \u39E
							 &Omicron; \u39F &Pi; \u3A0 &Rho; \u3A1 &Sigma; \u3A3 &Tau; \u3A4
							 &Upsilon; \u3A5 &Phi; \u3A6 &Chi; \u3A7 &Psi; \u3A8 &Omega; \u3A9
							 &alpha; \u3B1 &beta; \u3B2 &gamma; \u3B3 &delta; \u3B4 &epsilon; \u3B5
							 &zeta; \u3B6 &eta; \u3B7 &theta; \u3B8 &iota; \u3B9 &kappa; \u3BA
							 &lambda; \u3BB &mu; \u3BC &nu; \u3BD &xi; \u3BE &omicron; \u3BF
							 &pi; \u3C0 &rho; \u3C1 &sigmaf; \u3C2 &sigma; \u3C3 &tau; \u3C4
							 &upsilon; \u3C5 &phi; \u3C6 &chi; \u3C7 &psi; \u3C8 &omega; \u3C9
							 &thetasym; \u3D1 &upsih; \u3D2 &piv; \u3D6 &bull; \u2022
							 &hellip; \u2026 &prime; \u2032 &Prime; \u2033 &oline; \u203E
							 &frasl; \u2044 &weierp; \u2118 &image; \u2111 &real; \u211C
							 &trade; \u2122 &alefsym; \u2135 &larr; \u2190 &uarr; \u2191
							 &rarr; \u2192 &darr; \u2193 &harr; \u2194 &crarr; \u21B5
							 &lArr; \u21D0 &uArr; \u21D1 &rArr; \u21D2 &dArr; \u21D3 &hArr; \u21D4
							 &forall; \u2200 &part; \u2202 &exist; \u2203 &empty; \u2205
							 &nabla; \u2207 &isin; \u2208 &notin; \u2209 &ni; \u220B &prod; \u220F
							 &sum; \u2211 &minus; \u2212 &lowast; \u2217 &radic; \u221A
							 &prop; \u221D &infin; \u221E &ang; \u2220 &and; \u2227 &or; \u2228
							 &cap; \u2229 &cup; \u222A &int; \u222B &there4; \u2234 &sim; \u223C
							 &cong; \u2245 &asymp; \u2248 &ne; \u2260 &equiv; \u2261 &le; \u2264
							 &ge; \u2265 &sub; \u2282 &sup; \u2283 &nsub; \u2284 &sube; \u2286
							 &supe; \u2287 &oplus; \u2295 &otimes; \u2297 &perp; \u22A5
							 &sdot; \u22C5 &lceil; \u2308 &rceil; \u2309 &lfloor; \u230A
							 &rfloor; \u230B &lang; \u2329 &rang; \u232A &loz; \u25CA
							 &spades; \u2660 &clubs; \u2663 &hearts; \u2665 &diams; \u2666
							 &quot; \x22 &amp; \x26 &lt; \x3C &gt; \x3E O&Elig; \u152 &oelig; \u153
							 &Scaron; \u160 &scaron; \u161 &Yuml; \u178 &circ; \u2C6
							 &tilde; \u2DC &ensp; \u2002 &emsp; \u2003 &thinsp; \u2009
							 &zwnj; \u200C &zwj; \u200D &lrm; \u200E &rlm; \u200F &ndash; \u2013
							 &mdash; \u2014 &lsquo; \u2018 &rsquo; \u2019 &sbquo; \u201A
							 &ldquo; \u201C &rdquo; \u201D &bdquo; \u201E &dagger; \u2020
							 &Dagger; \u2021 &permil; \u2030 &lsaquo; \u2039 &rsaquo; \u203A
							 &euro; \u20AC &apos; \u0027 &lrm; "" &rlm; "" &#8236; "" &#8237; ""
							 &#8238; "" &#8212; \u2014
	};
	set data [string map [list "\]" "\\\]" "\[" "\\\[" "\$" "\\\$" "\\" "\\\\"] [string map $escapes $data]]
	regsub -all -- {&#([[:digit:]]{1,5});} $data {[format %c [string trimleft "\1" "0"]]} data
	regsub -all -- {&#x([[:xdigit:]]{1,4});} $data {[format %c [scan "\1" %x]]} data
	regsub -all -- {\\x([[:xdigit:]]{1,2})} $data {[format %c [scan "\1" %x]]} data
	set data [subst "$data"]
	return $data
}
}
putlog "Headlines $::headlines::ver loaded"