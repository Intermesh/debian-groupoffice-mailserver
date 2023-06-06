#!/usr/bin/php
<?php
require ("/etc/groupoffice/config.php");

echo "Applying group-office database credentials to /etc/dovecot/dovecot-sql.conf.ext and /etc/postfix/mysql_*\n";

$dovecotConnectStr = 'connect = "host='.$config['db_host'].' dbname='.$config['db_name'].' user='.$config['db_user'].' password='.$config['db_pass'].'"';

// will escape dollar followed by digest
function escape_backreference($x){
    return preg_replace('/\$(\d)/', '\\\$$1', $x);
}

$data = file_get_contents('/etc/dovecot/dovecot-groupoffice-sql.conf.ext');
$data = preg_replace('/connect = ".*"/', escape_backreference($dovecotConnectStr), $data);
file_put_contents('/etc/dovecot/dovecot-groupoffice-sql.conf.ext', $data);

function replacePostfixCred($config, $file) {
	
	$data = file_get_contents($file);
	$data = preg_replace('/user = .*/', 'user = '.$config['db_user'], $data);
	$data = preg_replace('/password = .*/', 'password = '.escape_backreference($config['db_pass']), $data);
	$data = preg_replace('/hosts = .*/', 'hosts = '.$config['db_host'], $data);
	$data = preg_replace('/dbname = .*/', 'dbname = '.$config['db_name'], $data);
	
	file_put_contents($file, $data);

}

replacePostfixCred($config, '/etc/postfix/mysql_virtual_alias_maps.cf');
replacePostfixCred($config, '/etc/postfix/mysql_virtual_mailbox_domains.cf');
replacePostfixCred($config, '/etc/postfix/mysql_virtual_mailbox_maps.cf');

echo "Installing postfixadmin module in Group-Office\n";
try{
	require('/usr/share/groupoffice/GO.php');

    \GO::setIgnoreAclPermissions();


	if(\go\core\App::get()->isInstalled() && !\GO::modules()->isInstalled('postfixadmin')){
		$module = new \GO\Base\Model\Module();
		$module->name = 'postfixadmin';
		if(!$module->save()) {
			var_dump($module->getValidationErrors());
		}	
	}
}
catch(\Exception $e){
	// ignore as GO might not be installed yet.
}

echo "done\n";
