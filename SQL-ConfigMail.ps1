        # Enable email http://sqlmag.com/powershell/script-your-database-mail-setup

$SMTPServer = ""
$SMTPUser = ""
$SMTPPassword = ""
$DBAOperator = ""
$DBAEmail = ""

        
        $svr = new-object ('Microsoft.SqlServer.Management.Smo.Server') 
        
        # Enable Database Mail
        $svr.Configuration.ShowAdvancedOptions.ConfigValue = 1
        $svr.Configuration.DatabaseMailEnabled.ConfigValue = 1
        $svr.Configuration.Alter()

        $mail = $svr.Mail
        # set up mail account
        $acct = new-object -TypeName Microsoft.SqlServer.Management.SMO.Mail.MailAccount -argumentlist $mail, $DBAOperator
        $acct.Description = 'Database Administrator Email'
        $acct.DisplayName = 'Database Administrator'
        $acct.EmailAddress = $DBAEmail
        $acct.ReplyToAddress = $DBAEmail
        $acct.Create()

        #Modify mail server
        $mlsrv = $acct.MailServers
        $mls = $mlsrv.Item(0)
        $mls.Rename($SMTPServer)
        $mls.EnableSsl = 'True'
        $mls.UserName = $SMTPUser
        $mls.SetPassword($SMTPPassword)
        $mls.Alter()
        $acct.Alter()

        # Create profile
        $mlp = new-object ('Microsoft.SqlServer.Management.Smo.Mail.MailProfile') ($mail, 'DBAMail', 'Database Administrator Mail Profile')
        $mlp.Create()
        $mlp.AddAccount($DBAOperator, 1)
        $mlp.Alter()

        # Add operator
        $oper = $DBAOperator
        $op = $svr.JobServer.Operators[$oper]
        if ($op.Count -gt 0) {
         $op.Drop()                        # The operator already exists, so drop it
        }
        $op = New-Object ('Microsoft.SqlServer.Management.Smo.Agent.Operator') ($svr.JobServer,$oper)
        $op.EmailAddress = $DBAEmail
        $op.Create()

        # Enable Mail on SQL SERVER AGENT
        Invoke-Sqlcmd -ServerInstance $ComputerName -Query "USE msdb
        GO
        EXEC master.dbo.xp_instance_regwrite
        N'HKEY_LOCAL_MACHINE',
        N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
        N'UseDatabaseMail',
        N'REG_DWORD', 1
        EXEC master.dbo.xp_instance_regwrite
        N'HKEY_LOCAL_MACHINE',
        N'SOFTWARE\Microsoft\MSSQLServer\SQLServerAgent',
        N'DatabaseMailProfile',
        N'REG_SZ',
        N'DBAMail'"

        # enable SQL Server Agent
        Invoke-Command -ScriptBlock { 
            restart-service 'SQLSERVERAGENT'
        }
