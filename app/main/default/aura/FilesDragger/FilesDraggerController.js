({
    init: function (cmp, event, helper) {
        helper.checkAuthorizing(cmp);
        helper.checkObjectFolder(cmp);
        helper.checkSubfolders(cmp);
    },
    
    
    downloadFile: function (cmp, event, helper) {
        var currentId = event.currentTarget.id.substring(0, event.currentTarget.id.length - 1);
        var files = cmp.get('v.files');
        var downloadFiles = [];
        for(var i = 0; i < files.length; i++) {
            if(files[i].id === currentId) {
                var file_path = files[i].DownloadLink;
                var a = document.createElement('A');
                a.href = file_path;
                a.download = file_path.substr(file_path.lastIndexOf('/') + 1);
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                
                var f ={};
                f.name = files[i].Name;
                f.type = files[i].Type;
                f.size = helper.returnFileSize(files[i].Size);
                downloadFiles[downloadFiles.length] = f;
            }
        }
        helper.updateLogFile(cmp, downloadFiles, 'Download file', cmp.get('v.recordFolderId'));
    },
    
    
    removeFile: function (cmp, event, helper) {
        cmp.set('v.spinner','slds-spinner_container');
        cmp.set('v.dropStyle','z-index:-1;');
        cmp.set('v.dropOpacity','opacity:0;');
        
        var currentId = event.currentTarget.id.substring(0, event.currentTarget.id.length - 1);
        var files = cmp.get('v.files');
        var removeFiles = [];
        for(var i = 0; i < files.length; i++) {
            if(files[i].id === currentId) {
                var f ={};
                f.name = files[i].Name;
                f.type = files[i].Type;
                f.size = helper.returnFileSize(files[i].Size);
                f.subfolder = files[i].Subfolder;
                removeFiles[removeFiles.length] = f;
            }
        }
        helper.removeFile(cmp, currentId, removeFiles);
    },
    
    openFile: function(cmp, event, helper) {
        var currentId = event.currentTarget.id.substring(0, event.currentTarget.id.length - 1);
        var files = cmp.get('v.files');
        var readFiles = [];
        for(var i = 0; i < files.length; i++) {
            if(files[i].id === currentId) {
                var f ={};
                f.name = files[i].Name;
                f.type = files[i].Type;
                f.size = helper.returnFileSize(files[i].Size);
                readFiles[readFiles.length] = f;
            }
        }
        helper.updateLogFile(cmp, readFiles, 'Read file', cmp.get('v.recordFolderId'));
        switch(cmp.get('v.driveName')) {
            case "gdrive":
        		window.open('https://drive.google.com/file/d/' + currentId + '/view?usp=drivesdk', '_blank');
                break;
            case "onedrive":
        		window.open('https://onedrive.live.com/?id=' + currentId, '_blank');
        		break;
            default: console.log("Sorry, error!");
        }
    },
    
    openRecordFolder: function(cmp, event, helper) {
        switch(cmp.get('v.driveName')) {
            case "gdrive":
        		window.open('https://drive.google.com/drive/u/0/folders/' + cmp.get('v.recordFolderId'), '_blank');
        		break;
            case "onedrive":
        		window.open('https://onedrive.live.com/?id=' + cmp.get('v.recordFolderId'), '_blank');
                break;
            default: console.log("Sorry, error!");
        }
    },
    
    openFolder: function(cmp, event, helper) {
        var currentId = event.currentTarget.id.substring(0, event.currentTarget.id.length - 1);
        switch(cmp.get('v.driveName')) {
            case "gdrive":
        		window.open('https://drive.google.com/drive/u/0/folders/' + currentId, '_blank');
        		break;
            case "onedrive":
        		window.open('https://onedrive.live.com/?id=' + currentId, '_blank');
                break;
            default: console.log("Sorry, error!");
        }
    },
    
    showSubfolders: function(cmp, event) {
        document.querySelector('#hiddenFiles').files = document.querySelector('#uploads').files;
        document.querySelector('#uploads').files = null;
        cmp.set('v.subfolderContainer', true);
        cmp.set('v.uploadContainer', false);
        
        var preview = document.querySelector('.preview');
        while(preview.firstChild) {
            preview.removeChild(preview.firstChild);
        }
        var para = document.createElement('p');
        para.textContent = 'No files are currently selected for upload.';
        preview.appendChild(para);
    },
        
    handleDragOver: function(cmp, event) {
        event.stopPropagation();
        event.preventDefault();
        event.dataTransfer.dropEffect = 'copy';
        cmp.set('v.dropStyle','z-index:1;');
        cmp.set('v.dropOpacity','opacity:1;');
    },
    
    handleDragLeave: function(cmp, event) {             
    	event.stopPropagation();
    	event.preventDefault();
    	event.dataTransfer.dropEffect = 'none';
    	cmp.set('v.dropStyle','z-index:-1;');
        if(cmp.get('v.filesEmpty')) cmp.set('v.dropOpacity','opacity:0;');
	},
    
    handleDrop: function(cmp, event, helper) {
        cmp.set('v.spinner','slds-spinner_container');
        cmp.set('v.dropStyle','z-index:-1;');
        cmp.set('v.dropOpacity','opacity:0;');
        
        event.stopPropagation();
        event.preventDefault();

        document.querySelector('#hiddenFiles').files = event.dataTransfer.files;
        cmp.set('v.subfolderContainer', true);
    },
    
    
    showUpload: function(cmp, event, helper) {
        cmp.set('v.uploadContainer', true);
    },
    
    
    hideUploadWindow: function(cmp, event, helper) {
        cmp.set('v.uploadContainer', false);
        document.querySelector('#uploads').files = null;
        var preview = document.querySelector('.preview');
        while(preview.firstChild) {
            preview.removeChild(preview.firstChild);
        }
        var para = document.createElement('p');
        para.textContent = 'No files are currently selected for upload.';
        preview.appendChild(para);
    },
    
    
    showFiles: function(cmp, event, helper) {
        var files = document.querySelector('#uploads').files;
        var preview = document.querySelector('.preview');
        
        while(preview.firstChild) {
            preview.removeChild(preview.firstChild);
        }
        cmp.set('v.choseFiles',false);
        
        if(files.length === 0) {
            cmp.set('v.choseFiles',false);
            var para = document.createElement('p');
            para.textContent = 'No files are currently selected for upload.';
            preview.appendChild(para);
        } else {
            cmp.set('v.choseFiles',true);
            var table = document.createElement('table');
            table.className = "slds-table slds-table_bordered slds-table_cell-buffer fixedLayout";
            preview.appendChild(table);
            var thead = document.createElement('thead');
            table.appendChild(thead);
            
            var headTR = document.createElement('tr');
            headTR.className = "slds-text-title_caps";
            thead.appendChild(headTR);
            
            var headTH = document.createElement('th');
            headTH.scope = "col";
            headTR.appendChild(headTH);
            
            var headDiv = document.createElement('div');
            headDiv.className = "slds-truncate";
            headDiv.title = "Name";
            headDiv.textContent = "Name";
            headTH.appendChild(headDiv);
            
            headTH = document.createElement('th');
            headTH.scope = "col";
            headTH.className = "columnWidth10";
            headTR.appendChild(headTH);
            
            headDiv = document.createElement('div');
            headDiv.className = "slds-truncate";
            headDiv.title = "Size";
            headDiv.textContent = "Size";
            headTH.appendChild(headDiv);
            
            var tbody = document.createElement('tbody');
            table.appendChild(tbody);
            
            for(var i = 0; i < files.length; i++) {
                var bodyTR = document.createElement('tr');
                
                var bodyTD = document.createElement('td');
                var bodyDiv = document.createElement('div');
                bodyDiv.className = "slds-truncate";
                bodyDiv.textContent = files[i].name;
                bodyTD.appendChild(bodyDiv);
                bodyTR.appendChild(bodyTD);
                
                bodyTD = document.createElement('td');
                bodyDiv = document.createElement('div');
                bodyDiv.className = "slds-truncate";
                bodyDiv.textContent = helper.returnFileSize(files[i].size);
                bodyTD.appendChild(bodyDiv);
                bodyTR.appendChild(bodyTD);
                
                tbody.appendChild(bodyTR);
            }
        }
    },
    
    
    confirmUpload: function(cmp, event, helper) {
        cmp.set('v.subfolderContainer', false);
        
        cmp.set('v.spinner','slds-spinner_container');
        cmp.set('v.dropStyle','z-index:-1;');
        cmp.set('v.dropOpacity','opacity:0;');
        
        var files = document.querySelector('#hiddenFiles').files;

        if(files.length > 10) {
            helper.showToast(cmp, event, helper, 'Upload Error!', 'error', 'You cannot upload more than 10 files at a time.');
            cmp.set('v.spinner','slds-spinner_container slds-hide');
            return;
        }
        var totalSize = 0;
        for(var i = 0; i < files.length; i++) {
            if(files[i].size > 83886080) {
                helper.showToast(cmp, event, helper, 'Upload Error!', 'error', 'You cannot upload files larger than 80 MB.');
            	cmp.set('v.spinner','slds-spinner_container slds-hide');
            	return;
            }
            totalSize += files[i].size;
        }
        if(totalSize > 209715200) {
            helper.showToast(cmp, event, helper, 'Upload Error!', 'error', 'You cannot upload more than 200 MB at a time.');
            cmp.set('v.spinner','slds-spinner_container slds-hide');
            return;
        }

        var action = cmp.get('c.createRecordFolder');
        action.setParams({ 
            'recordId' : cmp.get('v.recordId')
        });
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                for(var i = 0; i < files.length; i++) {
                    var file = files[i];
                    var reader = new FileReader();
                    reader.fileName = file.name;
                    reader.fileType = file.type;
                    reader.fileSize = helper.returnFileSize(file.size);
                    reader.fileSizeBytes = file.size;
                    switch(cmp.get('v.driveName')) {
                        case "gdrive":
                            reader.onload = function(event) {
                                var contentType = event.target.fileType || 'application/octet-stream';
                                helper.uploading(cmp, btoa(event.target.result), contentType, event.target.fileName, files.length, JSON.parse(response.getReturnValue()), event.target.fileSize, event.target.fileSizeBytes, cmp.get('v.selectedSubfolder'));
                            };
                            reader.readAsBinaryString(file);
                            break;
                        case "onedrive":
                            reader.onload = function(event) {
                                var contentType = event.target.fileType || 'application/octet-stream';
                                helper.uploading(cmp, new Uint8Array(event.target.result), contentType, event.target.fileName, files.length, JSON.parse(response.getReturnValue()), event.target.fileSize, event.target.fileSizeBytes, cmp.get('v.selectedSubfolder'));
                            };
                            reader.readAsArrayBuffer(file);
                            break;
                        default: console.log("Sorry, error!");
                    }
                }
            } else if (state === "ERROR") {
                var errors = response.getError();
                console.error(errors);
            }
        }));
        $A.enqueueAction(action);
    }
})