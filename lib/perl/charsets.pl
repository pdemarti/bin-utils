# charsets.pl -- Language-dependant character sets
#
# P. Demartines <Pierre.Demartines@motorola.com>  29-Dec-2000

# these definitions are from "Developing International Software for Windows 95 and Windows NT",
# ISBN 1-55615-840-8
my $base = "abcdefghijklmnopqrstuvwxyz";
$kLangDictChars{"danish"}    = $base."åæø";
$kLangDictChars{"english"}   = $base;
$kLangDictChars{"finnish"}   = $base."åäö";
$kLangDictChars{"french"}    = $base."àâçèéêëîïôùûü";
$kLangDictChars{"german"}    = $base."ßäöü";
$kLangDictChars{"italian"}   = $base."àèéìòù";
$kLangDictChars{"norwegian"} = $base."åæø";
$kLangDictChars{"portuguese"}= $base."ãáâçèéêíòóôõúü";
$kLangDictChars{"spanish"}   = $base."áéíóñúü";
$kLangDictChars{"swedish"}   = $base."åäö";

# special pseudo-languages for experiments
$kLangDictChars{"aefgis"}    = $base."ßàáâäçèéêëìíîïñòóôöùúûü";
$kLangDictChars{"hex"}	     = "0123456789ABCDEF";
$kLangDictChars{"uu"}        = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

$lower = 'abcdefghijklmnopqrstuvwxyzàáâãäåæçèéêëìíîïğñòóôõöøùúûüış';
$upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏĞÑÒÓÔÕÖØÙÚÛÜİŞ';

1;
