# check_mailbox
This command will check if a mailbox is available using pop(s) or imap(s). It supports performance data.

## Usage
```
check_imap [OPTIONS]
  [OPTIONS]:
  -H HOST           Full host string, i.E. "imaps://mail.local.ch:993" OR "pop3://mail.local.ch:143"
  -C CREDENTIAL     Username:Password, i.E. "user2:horsestaplebattery" (default: no auth)
  -M MAILBOX        Mailbox Name, needed for IMAP(s) only (default: INBOX)
  -I INSECURE       Allow insecure connections using IMAPs and POP3s (default: OFF)
  -S SSL            Try to use SSL/TLS for the connection (default: OFF)
  -V VERBOSE        Use verbose mode of CURL for debugging (default: OFF)
  -c CRITICAL       Critical threshold for execution in milliseconds (default: 3500)
  -w WARNING        Warning threshold for execution in milliseconds (default: 2000)
```

Example of connecting via pop3 on port 5050, setting a critical timeout of 3.2 seconds and providing username and password:
```
./check_mailbox.sh -H "pop3://pop3.mail.local.ch:5050" -c 3200 -C "user:p4$$w0rd_;)"
OK: MAILBOX LIST in 314 ms | value=314;2000;3200;0;3200 messagecount=2;
```

Example of connecting via insecure imaps on port 993 and verbosity on
```
./check_mailbox.sh -H "imaps://mailer.local.ch:993" -I
OK: MAILBOX LIST in 304 ms | value=304;2000;3200;0;3200 messagecount=2;
```

Example of connecting via pop3 setting the verbose flag and using the default port by omitting it:
```
./check_mailbox.sh -H "pop3://127.0.0.1" -c 3200 -C "user:p4ss"  -V
* Rebuilt URL to: pop3://127.0.0.1/
*   Trying 127.0.0.1...
* TCP_NODELAY set
* Connected to 127.0.0.1 (127.0.0.1) port 110 (#0)
< +OK Dovecot ready.
> CAPA
< +OK
< CAPA
< TOP
< UIDL
< RESP-CODES
< PIPELINING
< AUTH-RESP-CODE
< USER
< SASL PLAIN
< .
> AUTH PLAIN
< + 
> dXNlcgB1c2VyAHA0c3M=
< +OK server ready
> LIST
< +OK 2 messages
* Connection #0 to host 127.0.0.1 left intact
OK: MAILBOX LIST in 286 ms | value=286;2000;3500;0;3500 messagecount=2;
```

## Command Template
```
object CheckCommand "check-mailbox" {
  command = [ ConfigDir + "/scripts/check_mailbox.sh" ]
  arguments += {
    "-H" = "$chm_host$"
    "-C" = "user:password"
    "-M" = "INBOX"
    "-S" = {
           set_if = "$ssl$"
    }
    "-w" = "1000"
    "-c" = "2000"
  }
}
```
