# charsets.pl -- Language-dependant character sets
#
# P. Demartines <Pierre.Demartines@motorola.com>  29-Dec-2000

# these definitions are from "Developing International Software for Windows 95 and Windows NT",
# ISBN 1-55615-840-8
my $base = "abcdefghijklmnopqrstuvwxyz";
$kLangDictChars{"danish"}    = $base."���";
$kLangDictChars{"english"}   = $base;
$kLangDictChars{"finnish"}   = $base."���";
$kLangDictChars{"french"}    = $base."�������������";
$kLangDictChars{"german"}    = $base."����";
$kLangDictChars{"italian"}   = $base."������";
$kLangDictChars{"norwegian"} = $base."���";
$kLangDictChars{"portuguese"}= $base."��������������";
$kLangDictChars{"spanish"}   = $base."�������";
$kLangDictChars{"swedish"}   = $base."���";

# special pseudo-languages for experiments
$kLangDictChars{"aefgis"}    = $base."�����������������������";
$kLangDictChars{"hex"}	     = "0123456789ABCDEF";
$kLangDictChars{"uu"}        = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

$lower = 'abcdefghijklmnopqrstuvwxyz������������������������������';
$upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ������������������������������';

1;
