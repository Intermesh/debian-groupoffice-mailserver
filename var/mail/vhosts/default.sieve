require "fileinto";
# rule:[Spam]
if anyof (header :contains "X-Spam-Flag" "YES")
{
	fileinto "Spam";
	stop;
}

