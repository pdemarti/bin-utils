# tztime, revtztime -- Deals with dates in other timezones
#		       than "local" and "gmt".
# Performances:
# From 00:00:00 UTC, January 1, 1970 (0)
# To   00:00:00 UTC, January 1, 2020 (1577865600),
# by steps of 1/2 hour [+/- 15 minutes]  (1800 + RAND(-900,900)),
# revtztime called tztime twice for 84% of the time (738479 loops on 876485),
#               and three times for 16% of the time (138006 loops on 876485),
# --> average of 2.16 calls of tztime() per revtztime().
# 3.5 ms/call on a Sparc-5 (on the same workstation, gmtime() uses 0.13 ms/call).
# 
# WARNING: months begin with 00 here !!!  (ex:  10 -> november)
# 
# Pierre Demartines <demartin@icsi.berkeley.edu> Fri Jun 14

CONFIG:
  {
  package tztime;
  
  $debug = 0;
  $callstztime = 0;	# for perf measurement of revtztime()
  @wdays  = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat','   ');
  @lwdays  = ('Sunday','Monday','Tuesday','Wednesday',
              'Thursday','Friday','Satursday');
  @months = ('Jan','Feb','Mar','Apr','May','Jun',
             'Jul','Aug','Sep','Oct','Nov','Dec');
  @lmonths= ('January','February','March','April','May','June',
             'July','August','September','October','November','December');
  }


#------------------------------------------------------------------------
# &tztime($tzone, $time) gives the date corresponding to $time in the
# timezone $tzone. As for localtime() and gmtime(), as well as internally
# in UNIX systems, $time is expressed in number of seconds since
# since 00:00:00 UTC, January 1, 1970.
# Typical usage: 
# ($sec,$min,$hour,$mday,$mon,$year, @discarded) = &tztime($tzone, $time);
# Examples:
# &tztime('PDT', time);	# get the date now in the PDT time zone.
# &tztime("", time);	# get the local date now.
sub tztime
  {
  package tztime_tztime;
  
  $tztime::callstztime++;
  ($tzone, $time) = @_;
  $tzone =~ s/^PST$/-800/ ||
  $tzone =~ s/^PDT$/-700/ ||
  $tzone =~ s/^MST$/-700/ ||
  $tzone =~ s/^MDT$/-600/ ||
  $tzone =~ s/^CST$/-600/ ||
  $tzone =~ s/^CDT$/-500/ ||
  $tzone =~ s/^EST$/-500/ ||
  $tzone =~ s/^EDT$/-400/ ||
  $tzone =~ s/^AST$/-400/ ||
  $tzone =~ s/^NST$/-330/ ||
  $tzone =~ s/^UTC$/+000/ ||
  $tzone =~ s/^GMT$/+000/ ||
  $tzone =~ s/^BST$/+100/ ||
  $tzone =~ s/^MET$/+100/ ||
  $tzone =~ s/^CET$/+100/ ||
  $tzone =~ s/^EET$/+200/ ||
  $tzone =~ s/^CSET$/+200/ ||
  $tzone =~ s/^JST$/+900/ ||
  $tzone =~ s/^(UTC|GMT|)([+-]\d{1,2})$/$2 . "00"/e ||
  $tzone =~ s/^(UTC|GMT|)([+-]\d{3,4})$/$2/ ||
  $tzone =~ /^$/ ||
  ((print STDERR "tztime(\"$tzone\", $time): unknown TZONE. Assuming +000.\n"), $tzone = "+000");
  if ($tztime::debug) { print "tztime: tzone=$tzone\n"; }
  if ($tzone =~ /^$/) { return localtime($time); }
  if ($tzone =~ /^\-(.+)(..)$/) { return gmtime($time-(($1*60) + $2)*60); }
  if ($tzone =~ /^\+(.+)(..)$/) { return gmtime($time+(($1*60) + $2)*60); }
  print STDERR "tzonecorr(\"$tzone\"): internal error.\n";
  return 0; 
  }



#------------------------------------------------------------------------
# &revtztime($tzone, @date) reciprocal function of tztime(). That is:
# &revtztime($anyzone, &tztime($anyzone, $time)) yields $time.
# In other words, it provides the time of a date in a timezone. As
# usual, the time is in seconds since 00:00:00 UTC, January 1, 1970.
# Typical usage: 
# $time = &revtztime($tzone, $sec,$min,$hour,$mday,$mon,$year[,...]);
#         # arguments following $year are discarded.
# Examples:
# $time = &revtztime('PDT', @date);	# get the time of "PDT date".
# $time = &revtztime("", @date);	# get the time of local date.
sub revtztime
  {
  package tztime_revtztime;

  ($tzone, @d1) = @_;
  ($time2) = int((($d1[5]-70)*365.25+$d1[4]*30.5+$d1[3]+3)*24*3600);
  if ($tztime::debug)
    {
    print "tztime::arg: ", &main::date("", @_), "\n";
    print "tztime::time2#1: $time2: ", &main::date("", $tzone, $time2), "\n";
    }
  (@d2) = &main::tztime($tzone, $time2);
  if ($d2[4] > $d1[4] || $d2[5] > $d1[5])
    { $time2 -= $d2[3]*24*3600; @d2 = &main::tztime($tzone, $time2); }
  if ($tztime::debug)
    {
    print "tztime::time2#2: $time2: ", &main::date("", $tzone, $time2), "\n";
    }
  $time2 -= ((($d2[3]-$d1[3])*24+$d2[2]-$d1[2])*60+$d2[1]-$d1[1])*60+$d2[0]-$d1[0];
  if ($tztime::debug)
    {
    print "tztime::time2#3: $time2: ", &main::date("", $tzone, $time2), "\n";
    }
  @d2 = &main::tztime($tzone, $time2);
  if ($d2[4] < $d1[4])
    {
    $time2 -= (($d2[2]-$d1[2]-24)*60+$d2[1]-$d1[1])*60+$d2[0]-$d1[0];
    }
  else
    {
    $time2 -= ((($d2[3]-$d1[3])*24+$d2[2]-$d1[2])*60+$d2[1]-$d1[1])*60+$d2[0]-$d1[0];
    }
  if ($tztime::debug)
    {
    print "tztime::time2#4: $time2: ", &main::date("", $tzone, $time2), "\n";
    }
  return $time2;
  }



#------------------------------------------------------------------------
# NAME
#      date - convert date and time to string
#
# SYNOPSIS
#      require <tztime.pl>;
#
#      $string = &date($format, $tzone, $time);
#
# DESCRIPTION
#      return a string containing the date, according to
#      strftime(3C), but without the trailing "\n".
#
#      The Solaris definition is adopted for %C.
#
#      Conversion specifications added:
#      %f      format used in some fields of email headers
#              (eg. Received: )
#
# EXAMPLES
#     $datestr = &date("%C", "PDT", $time);
#     $datestr = &date("", "", $time);
#
# SEE ALSO
#     date(1), strftime(3C)
#
# AUTHOR
#     P. Demartines <demartin@gvasun.sps.mot.com> 31-Oct-1996
# 
#------------------------------------------------------------------------

sub date
  {
  package tztime_date;
  
  if ($#_ > 2)
    {
    ($format,$tzone,$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = @_;
    if ($#_ < 8) { $wday = 7; }		#unknown
    if ($#_ < 9) { $yday = "???"; }	#unknown
    }
  else
    {
    ($format, $tzone, $time) = @_;
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
      &main::tztime($tzone, $time);
    }
  
  if ($tzone =~ /^$/) { ($tzone = `date '+%Z'`) =~ s/\n//; }
  local($_) = $format;
  s/%%/%_/g;
    #  %%      same as %

  # constructs:
  s/^$/%C/;
    # no format specified --> %C
  s/%C/%a %b %e %T %Z %Y/g;	# Thu Oct  3 09:00:00 MET 1996
    #  %C      locale's date and time representation as produced by
    #          date(1)
  s/%f/%a, %e %b %T %Y %Z/g;	# Thu,  3 Oct 09:00:00 1996 MET
    #  %f      format used in some fields of email headers
    #          (this is not standard, i.e. not in strftime(3C))
  s/%c/%a %b %e %T %Y/g;	# Thu Oct  3 09:00:00 1996
    #  %c      locale's appropriate date and time representation
  s/%x/%D/g;
    #  %x      locale's appropriate date representation
  s/%X/%T/g;
    #  %X      locale's appropriate time representation
  s|%D|%m/%d/%y|g;
    #  %D      date as %m/%d/%y
  s/%r/%I:%M:%S %p/g;
    #  %r      appropriate time  representation  in  12-hour  clock
    #          format with %p
  s/%R/%H:%M/g;
    #  %R      time as %H:%M
  s/%T/%H:%M:%S/g;
    #  %T      time as %H:%M:%S

  # primitives:
  s/%a/$tztime::wdays[$wday]/ge;
    #  %a      locale's abbreviated weekday name
  s/%A/$tztime::lwdays[$wday]/ge;
    #  %A      locale's full weekday name
  s/%b/%h/g;
    #  %b      locale's abbreviated month name
  s/%B/$tztime::lmonths[$mon]/ge;
    #  %B      locale's full month name
  s/%d/sprintf("%02d", $mday)/ge;
    #  %d      day of month [1,31]; single digits are preceded by 0
  s/%e/sprintf("%2d", $mday)/ge;
    #  %e      day of month [1,31]; single digits are preceded by a
    #          space
  s/%h/$tztime::months[$mon]/ge;
    #  %h      locale's abbreviated month name
  s/%H/sprintf("%02d", $hour)/ge;
    #  %H      hour (24-hour clock) [0,23]; single digits are  pre-
    #          ceded by 0
  s/%I/sprintf("%02d", 1+($hour+11)%12)/ge;
    #  %I      hour (12-hour clock) [1,12]; single digits are  pre-
    #          ceded by 0
  s/%j/sprintf("%03d", $yday+1)/ge;
    #  %j      day number of year [1,366]; single digits  are  pre-
    #          ceded by 0
  s/%k/sprintf("%2d", $hour)/ge;
    #  %k      hour (24-hour clock) [0,23]; single digits are  pre-
    #          ceded by a blank
  s/%l/sprintf("%2d", 1+($hour+11)%12)/ge;
    #  %l      hour (12-hour clock) [1,12]; single digits are  pre-
    #          ceded by a blank
  s/%m/sprintf("%02d", $mon+1)/ge;
    #  %m      month number [1,12]; single digits are preceded by 0
  s/%M/sprintf("%02d", $min)/ge;
    #  %M      minute [00,59]; leading zero is  permitted  but  not
    #          required
  s/%n/\n/g;
    #  %n      insert a newline
  s/%p/$hour >= 12 ? "PM" : "AM"/ge;
    #  %p      locale's equivalent of either a.m. or p.m.
  s/%S/sprintf("%02d", $sec)/ge;
    #  %S      seconds [00,61]
  s/%t/\t/g;
    #  %t      insert a tab
  s/%u/sprintf("%d", $wday+1)/ge;
    #  %u      weekday as a decimal number [1,7], with 1 represent-
    #          ing Sunday
  s|%U|sprintf("%02d", int(($yday-$wday+7)/7))|ge;
  # (Is that correct ?)
    #  %U      week number of year as  a  decimal  number  [00,53],
    #          with Sunday as the first day of week 1
  s|%V|sprintf("%02d", (int(($yday-($wday-1)%7+8)/7)-1)%53+1)|ge;
  # (Is that correct ? --seems so, but I suspect a bug in date(1))
    #  %V      week number of the year as a decimal number [01,53],
    #          with  Monday  as  the first day of the week.  If the
    #          week containing 1 January has four or more  days  in
    #          the  new  year, then it is considered week 1; other-
    #          wise, it is week 53 of the previous  year,  and  the
    #          next week is week 1.
  s|%w|sprintf("%d", $wday)|ge;
    #  %w      weekday as a decimal number [0,6], with 0 represent-
    #          ing Sunday
  s|%W|sprintf("%02d", int(($yday-($wday-1)%7+7)/7))|ge;
  # (Is that correct ?)
    #  %W      week number of year as  a  decimal  number  [00,53],
    #          with Monday as the first day of week 1
  s/%y/sprintf("%02d", $year%100)/ge;
    #  %y      year within century [00,99]
  s/%Y/sprintf("%04d", 1900+$year)/ge;
    #  %Y      year, including the century (for example 1993)
  s/%Z/$tzone/g;
    #  %Z      time zone name or abbreviation, or no  bytes  if  no

  return $_;
  }

1;
