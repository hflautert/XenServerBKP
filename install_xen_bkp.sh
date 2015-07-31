#!/bin/bash
# XenServerBKP Installer
# hflautert@gmail.com


# Criando estrutura de diretórios
mkdir -p /mnt/XS_Backups/Pool_Metadatas
mkdir /mnt/XS_Backups/VMs_Exports
mkdir /mnt/XS_Backups/Hosts_Backups
mkdir /mnt/XS_Backups/Logs_Scripts

# Criando scripts
cat << 'FIM' > /usr/local/bin/Backup_Metadata
#!/bin/sh
# XenServer Metadata Backup

# Definindo Variaveis:
BACKUP_DIR="/mnt/XS_Backups/Pool_Metadatas"
SERVERNAME=$(echo $HOSTNAME | tr '[a-z]' '[A-Z]')
DATE=`date +%Y_%m_%d`
BASEFILE='POOL_METADATA_'$SERVERNAME
LOGFILE='/mnt/XS_Backups/Logs_Scripts/'$SERVERNAME'_Backup_Metadata_'$DATE'.log'

# Executando backup do metadado:
echo $DATE" - Iniciando geracao do dump do metadado do servidor "$SERVERNAME >> $LOGFILE
echo "" >> $LOGFILE
xe pool-dump-database file-name=$BACKUP_DIR/TEMP_$BASEFILE'_'$DATE >> $LOGFILE

# Validando geracao do dump database
if [ "$?" -ne "0" ]; then
       echo "Falha ao gerar dump do Metadado no caminho "$BACKUP_DIR"/"$BASEFILE'_'$DATE >> $LOGFILE
       echo "" >> $LOGFILE
       echo "Script finalizado com erro!" >> $LOGFILE
       echo "" >> $LOGFILE
       echo "**********************************************************************************************" >> $LOGFILE
       exit 1
fi
echo "Dump do metadado gerado com sucesso!" >> $LOGFILE
echo "" >> $LOGFILE
echo "Arquivo Gerado: "$BACKUP_DIR"/"$BASEFILE'_'$DATE >> $LOGFILE
echo "Horario da Criacao: "`date +%k:%M` >> $LOGFILE
echo "" >> $LOGFILE

# Removendo dumps antigos
rm $BACKUP_DIR/$BASEFILE*
mv $BACKUP_DIR/TEMP_$BASEFILE'_'$DATE $BACKUP_DIR/$BASEFILE'_'$DATE

echo "Dumps antigos removidos." >> $LOGFILE
echo "" >> $LOGFILE
echo "Script finalizado com sucesso!" >> $LOGFILE
echo "" >> $LOGFILE
echo "**********************************************************************************************" >> $LOGFILE
FIM

cat << 'FIM' > /usr/local/bin/Backup_Hosts
#!/bin/sh
# XenServer Hosts Backup

# Definindo Variaveis:
DOMINIO="dominio.com.br"
BACKUP_DIR="/mnt/XS_Backups/Hosts_Backups"
DATE=`date +%Y_%m_%d`

# Gerando lista dos hosts:
hosts=$(xe host-list | grep name-label | sed "s/          name-label ( RW): //")

# Executando backup para cada um dos hosts:
for i in $hosts;do
       SERVERNAME=$(echo $i | sed "s/.$DOMINIO//" | tr '[a-z]' '[A-Z]')
       LOGFILE='/mnt/XS_Backups/Logs_Scripts/'$SERVERNAME'_Backup_Hosts_'$DATE'.log'
       echo $DATE" - Iniciando backup do host "$SERVERNAME >> $LOGFILE
       echo "" >> $LOGFILE
               xe host-backup host=$i file-name=$BACKUP_DIR'/TEMP_'$SERVERNAME'_'$DATE
       if [ "$?" -ne "0" ]; then
               echo "Falha ao realizar o backup do host "$SERVERNAME >> $LOGFILE
               echo "" >> $LOGFILE
               echo "Script finalizado com erro!" >> $LOGFILE
               echo "" >> $LOGFILE
               echo "**********************************************************************************************" >> $LOGFILE
       fi

       echo "Backup realizado com sucesso!" >> $LOGFILE
       echo "" >> $LOGFILE
       echo "Arquivo Gerado: "$BACKUP_DIR'/'$SERVERNAME'_'$DATE >> $LOGFILE
       echo "Horario da Criacao: "`date +%k:%M` >> $LOGFILE
       echo "" >> $LOGFILE

       # Removendo dumps antigos
       rm $BACKUP_DIR/$SERVERNAME*
       mv $BACKUP_DIR'/TEMP_'$SERVERNAME'_'$DATE $BACKUP_DIR'/'$SERVERNAME'_'$DATE

       echo "Dumps antigos removidos." >> $LOGFILE
       echo "" >> $LOGFILE
       echo "Script finalizado com sucesso!" >> $LOGFILE
       echo "" >> $LOGFILE
       echo "**********************************************************************************************" >> $LOGFILE
done
FIM

cat << 'FIM' > /usr/local/bin/Snapshots_Diarios
#!/bin/sh
# XenServer VM Snapshots

# Definindo Variaveis:
DATE=`date +%Y_%m_%d`
SERVERNAME=$(echo $HOSTNAME | tr '[a-z]' '[A-Z]')
LOGFILE='/mnt/XS_Backups/Logs_Scripts/'$SERVERNAME'_Snapshots_Diarios_'$DATE'.log'
SNAP_LIST="/usr/local/bin/Vm_Snap_List.txt"

# Gerando lista de VMs com CustomField Snapshot = S
xe vm-list other-config:XenCenter.CustomFields.Snapshot=S |grep uuid|awk {'print $5'} > $SNAP_LIST

# Gerando Snapshots para as VMs listadas:
echo $DATE" - Iniciando snapshot das VMs marcadas com CustomField Snapshot = S" >> $LOGFILE
echo "" >> $LOGFILE
for uuid in `cat $SNAP_LIST` ;do
       VMNAME="`xe vm-param-get param-name=name-label uuid=$uuid`"
       OLD_SNAPS=$(xe snapshot-list is-a-snapshot=true | grep -R3 "$VMNAME" | grep uuid | sed "s/uuid ( RO)                : //")
       for i in $OLD_SNAPS;do
       echo "" >> $LOGFILE
       echo "Excluindo snapshot antigo uuid "$i  >> $LOGFILE
       xe snapshot-destroy uuid=$i
       done

       echo "Criando snapshot para a VM "$VMNAME >> $LOGFILE
       SNAPSHOT_UUID="`xe vm-snapshot vm="$VMNAME" new-name-label="$VMNAME"_$DATE`"

       xe template-param-set is-a-template=false ha-always-run=false uuid=$SNAPSHOT_UUID
       xe vm-param-set other-config:XenCenter.CustomFields.Snapshot=SNAP uuid=$SNAPSHOT_UUID
       xe vm-param-set other-config:XenCenter.CustomFields.Export=N uuid=$SNAPSHOT_UUID
       echo "Continuando com a proxima VM..." >> $LOGFILE
done

echo "Criacao de snapshots concluida!" >> $LOGFILE
echo "" >> $LOGFILE
echo "Final do script!" >> $LOGFILE
echo "" >> $LOGFILE
echo "**********************************************************************************************" >> $LOGFILE
FIM

cat << 'FIM' > /usr/local/bin/Exports_Semanais
#!/bin/sh
# XenServer VM Exports

# Definindo Variaveis:
DATE=`date +%Y_%m_%d`
SERVERNAME=$(echo $HOSTNAME | tr '[a-z]' '[A-Z]')
LOGFILE='/mnt/XS_Backups/Logs_Scripts/'$SERVERNAME'_Exports_Semanais_'$DATE'.log'
EXPORT_LIST="/usr/local/bin/Vm_Export_List.txt"
EXPORT_PATH=/mnt/XS_Backups/VMs_Exports
FS_PERC_USED="`df -h |grep XS_Backups|awk {'print $4'}`"
FS_TOTAL_LIVRE="`df -h |grep XS_Backups|awk {'print $3'}`"
FS_TOTAL_USED="`df -h |grep XS_Backups|awk {'print $2'}`"

# Gerando lista de VMs com CustomField Export = $1
xe vm-list other-config:XenCenter.CustomFields.Export=$1 |grep uuid|awk {'print $5'} > $EXPORT_LIST

# Exportando Snapshots das VMs marcadas com CustomField Export = $1
echo $DATE" - Iniciando export das VMs marcadas com CustomField Export = $1" >> $LOGFILE
echo "" >> $LOGFILE
for uuid in `cat $EXPORT_LIST` ;do
       VMNAME="`xe vm-param-get param-name=name-label uuid=$uuid`"
       echo "Excluindo exports antigos..."
       rm $EXPORT_PATH"/"$VMNAME* >> $LOGFILE
       SNAPUUID=$(xe snapshot-list is-a-template=false | grep -R3 $VMNAME | grep uuid | sed "s/uuid ( RO)                : //")
       FILENAME=$(xe snapshot-param-get param-name=name-label uuid=$SNAPUUID).xva
       echo "" >> $LOGFILE
       echo `date +%k:%M`" - Exportando arquivo /mnt/XS_Backups/VMs_Exports/$FILENAME ..." >> $LOGFILE
       xe snapshot-export-to-template snapshot-uuid=$SNAPUUID filename=/mnt/XS_Backups/VMs_Exports/$FILENAME
       echo `date +%k:%M`" - Exportacao da VM $VMNAME concluida. Continuando..." >> $LOGFILE
       echo "" >> $LOGFILE
done

echo "Exports concluidos!" >> $LOGFILE
echo "" >> $LOGFILE
echo "Final do script!" >> $LOGFILE
echo "" >> $LOGFILE
echo "**********************************************************************************************" >> $LOGFILE
FIM

# Aplicando permissão de execução nos sripts
chmod +x /usr/local/bin/Backup_Metadata
chmod +x /usr/local/bin/Backup_Hosts
chmod +x /usr/local/bin/Snapshots_Diarios
chmod +x /usr/local/bin/Exports_Semanais

cat << 'FIM' >>  /etc/crontab
#Backup Metadados: Diariamente a 02h
0 2 * * * /usr/local/bin/Backup_Metadata

#Backup Hosts do Pool: Todo domingo as 09h
0 9 * * sat /usr/local/bin/Backup_Hosts

#Snapshot das VMs: Diario as 01h
0 6 * * * /usr/local/bin/Snapshots_Diarios

#Exports das VMs, a cada dia da semana as 02h
0 2 * * 7 root /usr/local/bin/Exports_Semanais DOM
0 2 * * 1 root /usr/local/bin/Exports_Semanais SEG
0 2 * * 2 root /usr/local/bin/Exports_Semanais TER
0 2 * * 3 root /usr/local/bin/Exports_Semanais QUA
0 2 * * 4 root /usr/local/bin/Exports_Semanais QUI
0 2 * * 5 root /usr/local/bin/Exports_Semanais SEX
0 2 * * 6 root /usr/local/bin/Exports_Semanais SAB
FIM

echo "
####################################
# Estrutura criada, editar dominio #
# vi /usr/local/bin/Backup_Hosts   #
####################################"
