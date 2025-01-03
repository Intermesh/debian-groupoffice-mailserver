#!/usr/bin/php
<?php
require ("/etc/groupoffice/config.php");
/* @var $config array */

echo "Applying group-office database credentials to /etc/dovecot/dovecot-sql.conf.ext and /etc/postfix/mysql_*\n";


// will escape dollar followed by digest
function escape_backreference($x){
    return preg_replace('/\$(\d)/', '\\\$$1', $x);
}


function replaceDovecotCred($config, $file) {
	$dovecotConnectStr = 'connect = "host='.$config['db_host'].' dbname='.$config['db_name'].' user='.$config['db_user'].' password='.$config['db_pass'].'"';

	$data = file_get_contents($file);
	$data = preg_replace('/connect = ".*"/', escape_backreference($dovecotConnectStr), $data);
	file_put_contents($file, $data);
}

replaceDovecotCred($config,'/etc/dovecot/dovecot-groupoffice-sql.conf.ext');
replaceDovecotCred($config,'/etc/dovecot/domain-owner-sql.conf.ext');
replaceDovecotCred($config,'/etc/dovecot/dovecot-dict-sql.conf.ext');


$data = file_get_contents('/etc/opendkim.conf');
$data = preg_replace('/SigningTable.*/', 'SigningTable dsn:mysql://'.$config['db_user'].':'.escape_backreference($config['db_pass']).'@'.$config['db_host'].'/'.$config['db_name'].'/table=community_maildomains_dkim?keycol=domain?datacol=id', $data);
$data = preg_replace('/KeyTable.*/', 'KeyTable dsn:mysql://'.$config['db_user'].':'.escape_backreference($config['db_pass']).'@'.$config['db_host'].'/'.$config['db_name'].'/table=community_maildomains_dkim?keycol=id?datacol=domain,selector,privateKey', $data);
file_put_contents('/etc/opendkim.conf', $data);


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
