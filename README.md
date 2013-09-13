Description
-----------
Dynamic DNS updates via PowerShell for a single subdomain using [Amazon's Route 53] (http://aws.amazon.com/route53/) DNS service.  



Requirements
------------
1. AWS Route 53 Account. [Signup here.] (http://aws.amazon.com/route53/)
2. Existing Route 53 Hosted Zone with a Zone ID.
3. PowerShell 3.0. [Download here.] (http://www.microsoft.com/en-us/download/details.aspx?id=34595)
4. .NET Framework 4.0 [Download here.] (http://www.microsoft.com/en-us/download/details.aspx?id=17851)


Platform
--------
The release was tested on:

	* Windows 7 Ultimate 64-Bit with Service Pack 1
	* Windows 7 Enterprise 64-Bit with Service Pack 1
 


Recommendations 
---------------
Ideally you should create a new AWS IAM user account specifically for the the DNS function. 

For additional security, you should also setup a IAM Policy for the user account that can only interact with the Route 53 service. Here is an Example Policy:

	{
	  "Version": "2012-10-17",
	  "Statement": [
	    {
	      "Action": [
	        "route53:ChangeResourceRecordSets",
	        "route53:ListResourceRecordSets",
	        "route53:GetChange"
	      ],
	      "Sid": "Stmt000000000000000",
	      "Resource": [
	        "arn:aws:route53:::hostedzone/ZONEIDHERE",
	        "arn:aws:route53:::change/*"
	      ],
	      "Effect": "Allow"
	    }
	  ]
	}



Setup
-----
1. Save the script to an accessible location.
	C:\Users\UserName\Documents\Scripts\R53DnyDns.ps1

2. Create 3 Windows environment variables with the following names and values:

	 >* Name: AwsDNSAccessKeyID
	 >    * Set to your AWS User Account Key
	 >
	 >* Name: AwsDNSSecretKey
	 >    * Set to your AWS User Account Secret Key
	 >
	 >* Name: AwsZoneID
	 >    * Set to your Route 53 Zone ID
	 >
	 >* You may have to restart your computer for these to take effect.
	
3. Open the script and find the line
		$DynamicSubzone = "yourhost.domain.com"  #FQDN of the sub domain
* Modify yourhost.domain.com to your values and save the script.


Usage
-----
Create a scheduled task in Windows Task Scheduler to run the script every 15 minutes.
* For the first few runs remove -WindowStyle hidden and add instead -noexit and test the script from the Run box or a command prompt. This will allow you to see if there are any problems. Once everything is configured correctly and runs without issues create the scheduled task and use the other command.

First few runs from Command Prompt or Run...:

    powershell -version  3.0 -noexit -file "C:\Users\UserName\Documents\Scripts\R53DnyDns.ps1"
	
Once everything is running correctly Task Scheduler:

    powershell -version  3.0 -WindowStyle hidden -file "C:\Users\UserName\Documents\Scripts\R53DnyDns.ps1"


License and Author
------------------

<table>
	<tbody>
		<tr>
			<td align="left"><strong>Author</strong></td>
			<td align="left">Steven Gorrell (steven (at) stevengorrell (dot) com)
		</tr>
		<tr>
			<td align="left"><strong>Copyright</strong>
			<td align="left">Copyright (c) 2013, Steven Gorrell.</td>
		</tr>
	</tbody>
</table>


Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.