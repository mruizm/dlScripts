#!/usr/bin/perl
use MIME::Base64;

sub getHttpsStrings
{
        my $customer = $ARGV[0];
        open (FILE, '/var/spool/mail/rumarco');
        my @nodesTimed = ();
        my $tmpFolder = "/usr/local/nagios/share/log";
        my $finalFile = "$tmpFolder/$customer.count";
        my $finalTimedNodesCoded = "$tmpFolder/$customer.timed.coded";
        my $finalTimedNodes = "$tmpFolder/$customer.timed";
        system("rm -f $tmpFolder/$customer.timed > /dev/null 2>&1");

        while (<FILE>)
        {
                chomp;
                #Matches Subject and From boundry from email
                if ( /^Subject:(.*)\s(\[$customer\]$)/ .. /^--(.*)--$/ )
                {
                        my $lineData = $_;
                        my $lineData_not_100;
                        chomp($lineData);
                        if ( /(\%OK:)\s((\d)(\d)?(.)((\d\d)?))/ )
                        {
                                print "Nodes responding to HTTPS: $2%\n";
                                system("touch $tmpFolder/$customer.timed > /dev/null 2>&1");
                                $upValued = $2;
                        }
                        if ($lineData =~ m/(^Total\sCount:)\s([\d]+)=/ )
                        {
                                open (MYFILE, "> $finalFile");
                                print MYFILE "$2\n";
                                close (MYFILE);
                                #print "$2\n";
                        }
                        if (/Content-Transfer-Encoding: base64/ .. /^--(.*)--$/)
                        {
                                if ($lineData =~ m/^[\w\d]+$/)
                                {
                                	#print "$lineData\n";
                                	chomp;
                                	open (MYFILETIMED, ">> $finalTimedNodesCoded");
                                	print MYFILETIMED "$_\n";
                                	close (MYFILETIMED);
                                }
                        }
                }
        }
        open(FILE, $finalTimedNodesCoded);
   		while (read(FILE, $buf, 60*57)) 
   		{
       		open (MYFILETIMED, ">> $finalTimedNodes");
			print MYFILETIMED decode_base64($buf);;
            close (MYFILETIMED);
       		#print decode_base64($buf);
   		}
                
        if (($upValued >= 95))
        {
                exit 0;
        }
        if (($upValued < 95) && ($upValued >= 90))
        {
                exit 1;
        }
    if (($upValued < 90))
    {
       exit 2;
    }
}
getHttpsStrings();
#Make script for HealthCheck report
#Make historic of HTTPS report, add date and stdout to file
#Make in case /usr/local/nagios/share/log is not created
