#!/bin/sh
# -*-Perl-*-
exec perl -x -- "$0" "$@"
#!perl -w

$debug = 0;

sub test_dvb_adapter(\@) {
  my($inc) = @_;
  my($vars)="";
  foreach $i (@$inc) {
    $vars .= "\"$i\" ";
  }
  unlink("dvbdevwrap.h");
  unlink("dvbdev.h");
  unlink("config-dvb/dvbdev.h");
  $cmd = "cd config-dvb && make $vars" . ($debug ? "" : "2>/dev/null 1>/dev/null");
  print "$cmd\n" if($debug);

  #test linux-version >= 2.6.22
  system("ln -sf chkdvb-2.6.v4l.c config-dvb/chkdvb.c");
  if(system("$cmd") == 0) {
    print "Found dvbdev.h from 2.6.22 or later\n";
    `echo "DVB_DEFINE_MOD_OPT_ADAPTER_NR(adapter_nr);" >> dvbdevwrap.h`; 
    `echo "#define wrap_dvb_reg_adapter(a, b, c) dvb_register_adapter(a, b, c, &dvblb_basedev->dev, adapter_nr)" >> dvbdevwrap.h`; 
    return 0;
  }
  
  #test linux-version >= 2.6.18
  system("ln -sf chkdvb-2.6.18.c config-dvb/chkdvb.c");
  if(system("$cmd") == 0) {
    print "Found dvbdev.h from 2.6.18 or later\n";
    `echo "#define wrap_dvb_reg_adapter(a, b, c) dvb_register_adapter(a, b, c, &dvblb_basedev->dev)" >> dvbdevwrap.h`;
    return 0;
  }
  
  #test linux-version >= 2.6.14
  system("ln -sf chkdvb-2.6.14.c config-dvb/chkdvb.c");
  if(system("$cmd") == 0) {
    print "Found dvbdev.h from 2.6.14 or later\n";
    `echo "#define wrap_dvb_reg_adapter dvb_register_adapter" >> dvbdevwrap.h`;
    return 0;
  }

  #test linux-version >= 2.6.5
  system("ln -sf chkdvb-2.6.5.c config-dvb/chkdvb.c");
  if(system("$cmd") == 0) {
    print "Found dvbdev.h from 2.6.5 or later\n";
    print "But this is an unsupported kernel!\n";
    return 1;
  }

  #maybe kernel headers aren't available.  let's use canned dvbdev.h
  #this is dangerous!
  $uname = `uname -r`;
  if($uname =~ /2\.6\.(\d\d)/ && $1 >= 22) {
    system("ln -sf ../dvbdev-2.6.v4l.h config-dvb/dvbdev.h"); 
    system("ln -sf chkdvb-2.6.v4l.c config-dvb/chkdvb.c"); 
    if(system("$cmd") == 0) {
      print "Found 2.6.22 or later kernel, but no dvbdev.h\n";
      print "Using canned header\n";
      `echo "DVB_DEFINE_MOD_OPT_ADAPTER_NR(adapter_nr);" >> dvbdevwrap.h`; 
      `echo "#define wrap_dvb_reg_adapter(a, b, c) dvb_register_adapter(a, b, c, &dvblb_basedev->dev, adapter_nr)" >> dvbdevwrap.h`; 
      system("ln -sf dvbdev-2.6.v4l.h dvbdev.h"); 
      return 0;
    }
  }
  elsif($uname =~ /2\.6\.2[01]/ ||
        $uname =~ /2\.6\.1[89]/) {
    system("ln -sf ../dvbdev-2.6.18.h config-dvb/dvbdev.h");
    system("ln -sf chkdvb-2.6.18.c config-dvb/chkdvb.c");
    if(system("$cmd") == 0) {
      print "Found 2.6.18 or later kernel, but no dvbdev.h\n";
      print "Using canned header\n";
      `echo "#define wrap_dvb_reg_adapter(a, b, c) dvb_register_adapter(a, b, c, &dvblb_basedev->dev)" >> dvbdevwrap.h`;
      system("ln -sf dvbdev-2.6.18.h dvbdev.h");
      return 0;
    }
  }
  elsif($uname =~ /2\.6\.1[4-7]/) {
    system("ln -sf ../dvbdev-2.6.14.h config-dvb/dvbdev.h");
    system("ln -sf chkdvb-2.6.14.c config-dvb/chkdvb.c");
    if(system("$cmd") == 0) {
      print "Found 2.6.14 or later kernel, but no dvbdev.h\n";
      print "Using canned header\n";
      `echo "#define wrap_dvb_reg_adapter dvb_register_adapter" >> dvbdevwrap.h`;
      system("ln -sf dvbdev-2.6.14.h dvbdev.h");
      return 0;
    }
  }
  print "Could not identify kernel\n";
  return 1;
}

exit(test_dvb_adapter(@ARGV));
