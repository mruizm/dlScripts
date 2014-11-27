#!/usr/bin/perl
use lib '/root/home/hpamarui/dlScripts/IPC-Run-0.92/blib/lib/';
use lib '/root/home/hpamarui/dlScripts/Mail-Sender-0.8.23/blib/lib/';
use Mail::Sender;
use IO::Pipe;
use IPC::Run qw( run timeout );

my $cust_file_out = "/opt/OpC_local/OMU_Reports/CNodes/tmp";
my $hostname_om = `hostname`;
chomp($hostname_om);
my $sender = Mail::Sender->new({
				on_errors => 'die',
    			smtp => 'smtp.hp.com',
        		from => "nodeaudit\@$hostname_om.omc.hp.com",
        		encoding => "Quoted-printable",
            });
my @customerFileNames = ();


#Sub that checks if node list directory exists
sub checkNodeListDir
{
        my $custNodeList = `ls -l $cust_file_out > /dev/null 2>&1`;
        return $?;
}

#sub that checks if in the node list directory exists files to process
sub checkNodeListFiles
{
        my $custFileCount = `ls -l $cust_file_out | wc -l`;
        return $custFileCount;
}

#sub for node list https test processing
sub custFileProcessing
{
        if (checkNodeListDir() ne "0" )
        {
                print "Node list directory ($cust_file_out) does not exists.\n";
                print "Cannot continue with script.\n";
        if (ref ($sender->MailMsg({to =>'mruizm@hp.com', subject => 'dlScripts: HTTPS Node Audit',
                         msg => "Node list directory ($cust_file_out) does not exists.\n\n---EOF---"})))
        {
                        print "Error sent to Nagios.\n"
                }
                else
                {
                        die "$Mail::Sender::Error\n";
                }
        }
        else
        {
                if (checkNodeListFiles() >= 2 )
                {
                        $pipe = IO::Pipe->new();
                        system("rm -f $cust_file_out/*.timed.txt > /dev/null 2>&1");
                        $dirNodeList = "ls -l $cust_file_out | grep -v total | awk \'{print \$9}\' | grep \"nodes\$\"";
                        $pipe->reader(split('  ', $dirNodeList));
                        while (<$pipe>)
                        {
                                my $custFileName = $_;
                                chomp($custFileName);
                                push(@customerFileNames, $custFileName);
                        }
                        print "Node list found...\n";
                        foreach (@customerFileNames)
                        {
                                print "Processing file $_...\n";
                                my $customerName = $_;
                                chomp($customerName);
                                $customerName =~ /([C_(A-Za-z0-9)]+)\s*/;
                                $customerName = $1;
                                my $goodNodes = 0;
                                my $badNodes = 0;
                                my $totalNodes = `wc -l $cust_file_out/$_ | awk '{print \$1}'`;
                                chomp($totalNodes);
                                my $currentNodeCount = 0;
                                my $goodPor = 0;
                                my $badPor = 0;

                                open (MYFILE, "$cust_file_out/$_");
                                $timedNodes = "$cust_file_out/$_.timed.txt";
                                while (<MYFILE>)
                                {
                                        chomp;
                                        my $h;
                                        my @cmd = ("bbcutil", "-ping", "https://$_");
                                        eval
                                        {
                                                run \@cmd, \$in, '&>', \$out, '&>', \$err, timeout( 2 );
                                                $goodNodes++;
                                                $currentNodeCount++;
                                                print "\rProcessing: $currentNodeCount of $totalNodes nodes / Nodes OK: $goodNodes / Nodes Timedout: $badNodes";
                                        };

                                        if ( $@ )
                                        {
                                                $badNodes++;
                                                $currentNodeCount++;
                                                open (MYFILE_NODES, ">> $timedNodes");
                                                print MYFILE_NODES "$_\n";
                                            print "\rProcessing: $currentNodeCount of $totalNodes nodes / Nodes OK: $goodNodes / Nodes Timedout: $badNodes";
                                        }
                                }
                                print MYFILE_NODES "--EOF [$customerName]--";
                                close (MYFILE_NODES);
                                close (MYFILE);
                                print "\n";
                                my $goodPor = ($goodNodes * 100)/$totalNodes;
                                my $badPor = ($badNodes * 100)/$totalNodes;
                                print "%OK: $goodPor / %Timedout: $badPor";
                                print "\n";
                                print "\n";
                                if (-e $timedNodes)
                                {

                                        $sender->MailFile({to => 'mruizm@hp.com',
                                        subject => "dlScripts: HTTPS Node Audit [$customerName]",
                                        msg => "%OK: $goodPor / %Timedout: $badPor\nTotal Count: $totalNodes",
                                        encoding => "Quoted-printable",
                                        file => "$timedNodes"});
                                        #print "To view timedout nodes, please check file $timedNodes\n";
                                }
                                else
                                {
                                        $sender->MailMsg({to =>'mruizm@hp.com', subject => "dlScripts: HTTPS Node Audit [$customerName]",
                         msg => "%OK: $goodPor / %Timedout: $badPor\nTotal Count: $totalNodes\n\n--EOF [$customerName]--"});
                                }

                        }
                }
                else
                {
                        print "No customer node list file found in $cust_file_out\n";
                        print "Cannot continue with script.\n";

                        if (ref ($sender->MailMsg({to =>'mruizm@hp.com', subject => 'dlScripts: HTTPS Node Audit',
                         msg => "No customer node list file found in $cust_file_out\n\n---EOF---"})))
                		{
                        	print "Error sent to Nagios.\n";
                        }
                        else
                        {
                        	die "$Mail::Sender::Error\n";
                        }
                }
        }
}

#call to main processing sub
custFileProcessing();
#Make use of C_<Customer> argument to only check that nodegroup for timedout nodes.
