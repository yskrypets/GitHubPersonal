({
    checkAuthorizing : function(cmp) {
        var action = cmp.get('c.checkAuthorizing');
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var resp = response.getReturnValue();
                cmp.set('v.authorized', resp.auth);
                cmp.set('v.driveName', resp.driveName);
            } else if (state === "ERROR") {
                cmp.set('v.authorized', false);
            }
        }));
        $A.enqueueAction(action);
    },
    
    checkObjectFolder : function(cmp) {
        var action = cmp.get('c.checkFolder');
        action.setParams({ 
            'recordId' : cmp.get('v.recordId')
        });
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var resp = JSON.parse(response.getReturnValue());
                if(resp.available) {
                    this.getFiles(cmp);
                }
                cmp.set('v.available', resp.available);
                if(resp.parentObjectLabel != null && resp.parentObjectLabel != '') {
                	cmp.set('v.parentObjectLabel', resp.parentObjectLabel);
                    cmp.set('v.parentRecordId', resp.parentRecordId);
                    cmp.set('v.showParent', 'float:right;');
                }
            } else if (state === "ERROR") {
                var errors = response.getError();
                console.error(errors);
            }
        }));
        $A.enqueueAction(action);
    },
    
    checkSubfolders : function(cmp) {
        var action = cmp.get('c.getSubfolders');
        action.setParams({ 
            'recordId' : cmp.get('v.recordId')
        });
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                cmp.set('v.subfolders', JSON.parse(response.getReturnValue()));
            } else if (state === "ERROR") {
                var errors = response.getError();
                console.error(errors);
            }
        }));
        $A.enqueueAction(action);
    },
    
    getFiles : function(cmp) {
        var action = cmp.get('c.getFiles');
        action.setParams({ 
            'recordId' : cmp.get('v.recordId')
        });
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                cmp.set('v.recordFolderId', response.getReturnValue().recordFolderId);
                var files = response.getReturnValue().fileList;
                if(files == null) {
                    cmp.set('v.filesEmpty', false);
                    cmp.set('v.dropOpacity','opacity:1;');
                } else {
                    cmp.set('v.filesEmpty', true);
                    cmp.set('v.dropOpacity','opacity:0;');
                }
                cmp.set('v.files', files);
            } else if (state === "ERROR") {
                var errors = response.getError();
                console.error(errors);
            }
            cmp.set('v.spinner','slds-spinner_container slds-hide');
        }));
        $A.enqueueAction(action);
    },
        
    
    
    uploading: function(cmp, fileContent, contentType, fileName, totalFiles, tokenFolderId, size, fileSizeBytes, subfolderName) {
        const hdl = this;
        switch(cmp.get('v.driveName')) {
            case "gdrive":
                const boundary = 'googleProject';
                const delimiter = "\r\n--" + boundary + "\r\n";
                const close_delim = "\r\n--" + boundary + "--";
                
                var allFilesUploaded = false;
                
                var metadata = {
                    'name': fileName,
                    'parents': [tokenFolderId[cmp.get('v.selectedSubfolder')] ? tokenFolderId[cmp.get('v.selectedSubfolder')] : tokenFolderId.folderId],
                    'properties': {
                        'parentId': cmp.get('v.recordId'),
                        'subfolder': cmp.get('v.selectedSubfolder')
                    }
                };
                
                var multipartRequestBody =
                    delimiter +
                    'Content-Type: application/json\r\n\r\n' +
                    JSON.stringify(metadata) +
                    delimiter +
                    'Content-Type: ' + contentType + '\r\n' +
                    'Content-Transfer-Encoding: base64\r\n' +
                    '\r\n' +
                    fileContent +
                    close_delim;
                
                jQuery.ajax({
                    type:"POST",
                    beforeSend: function(request) {
                        request.setRequestHeader("Authorization", 'Bearer ' + tokenFolderId.token);
                    },
                    url: "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart",
                    data: multipartRequestBody,
                    contentType: 'multipart/mixed; boundary="' + boundary + '"',
                    complete: function(msg) {
                        cmp.set('v.uploaded', cmp.get('v.uploaded') + 1);
                        var newFiles = cmp.get('v.newFiles');
                        newFiles[newFiles.length] = {"name":fileName,"type":contentType,"size":size};
                        cmp.set('v.newFiles', newFiles);
                        if(cmp.get('v.uploaded') >= totalFiles) {
                            hdl.getFiles(cmp);
                            hdl.updateLogFile(cmp, cmp.get('v.newFiles'), 'Add file', tokenFolderId.folderId);
                            cmp.set('v.uploaded', 0);
                            hdl.showToast(cmp, null, null, 'Upload Complete!', 'info', 'File upload successful.');
                            cmp.set('v.newFiles', []);
                        }
                    }
                });
                break;
            case "onedrive":
                var requestBody = {
                    "item": {
                        "@odata.type": "microsoft.graph.driveItemUploadableProperties",
                        "@microsoft.graph.conflictBehavior": "rename",
                        "name": fileName
                    }
                };
                jQuery.ajax({
                    type:"POST",
                    beforeSend: function(request) {
                        request.setRequestHeader("Authorization", 'Bearer ' + tokenFolderId.token);
                    },
                    url: "https://graph.microsoft.com/v1.0/me/drive/items/" + (tokenFolderId[subfolderName] ? tokenFolderId[subfolderName] : tokenFolderId.folderId) + ":/" + fileName + ":/createUploadSession",
                    data: JSON.stringify(requestBody),
                    contentType: 'application/json',
                    complete: function(msg) {
                        console.log(msg);
                        hdl.uploadHelper(cmp, msg.responseJSON.uploadUrl, fileContent, fileName, contentType, size, fileSizeBytes, totalFiles, tokenFolderId, subfolderName, 0);
                    }
                });
                break;
            default: console.log("Sorry, error!");
        }
    },
    
    
    uploadHelper: function(cmp, uploadUrl, fileContent, fileName, contentType, size, fileSizeBytes, totalFiles, tokenFolderId, subfolderName, startByte) {
        const hdl = this;
        var endByte = fileContent.length < (10 * 1024 * 1024) ? fileSizeBytes - 1 : startByte + (10 * 1024 * 1024) - 1;
        var tempContent = fileContent.length < (10 * 1024 * 1024) ? fileContent : fileContent.slice(0, (10 * 1024 * 1024));
        
        var xhr = new XMLHttpRequest();
        xhr.open('PUT', uploadUrl, true);
        xhr.setRequestHeader('Authorization', 'Bearer ' + tokenFolderId.token);
        xhr.setRequestHeader('Content-Range', 'bytes ' + startByte + '-' + endByte + '/' + fileSizeBytes);
        xhr.responseType = 'json';
        xhr.onloadend = function(e) { 
            //console.log(xhr.response);
            if(tempContent.length < fileContent.length) {
                hdl.uploadHelper(cmp, uploadUrl, fileContent.slice((10 * 1024 * 1024), fileContent.length), fileName, contentType, size, fileSizeBytes, totalFiles, tokenFolderId, subfolderName, startByte + (10 * 1024 * 1024));
            } else {
                hdl.closeUploadSession(uploadUrl, tokenFolderId);
                cmp.set('v.uploaded', cmp.get('v.uploaded') + 1);
                var newFiles = cmp.get('v.newFiles');
                newFiles[newFiles.length] = {"name":fileName,"type":contentType,"size":size};
                cmp.set('v.newFiles', newFiles);
                if(cmp.get('v.uploaded') >= totalFiles) {
                    hdl.getFiles(cmp);
                    hdl.updateLogFile(cmp, cmp.get('v.newFiles'), 'Add file', tokenFolderId.folderId);
                    cmp.set('v.uploaded', 0);
                    hdl.showToast(cmp, null, null, 'Upload Complete!', 'info', 'Files upload successful.');
                    cmp.set('v.newFiles', []);
                }
            }
        };
            
        xhr.send(new Blob([tempContent], {type: contentType}));
    },
    
    
    closeUploadSession : function(uploadUrl, tokenFolderId) {
        var xhr = new XMLHttpRequest();
        xhr.open('DELETE', uploadUrl, true);
        xhr.setRequestHeader('Authorization', 'Bearer ' + tokenFolderId.token);
        xhr.onloadend = function(e) { }
        xhr.send();
    },
    
    
    removeFile : function(cmp, fileId, removeFiles) {
        const hdl = this;
        var action = cmp.get('c.remove');
        action.setParams({ 
            'recordId' : cmp.get('v.recordId'),
            'fileId' : fileId,
            'fileName' : removeFiles[0].name,
            'subfolder' : removeFiles[0].subfolder
        });
        action.setCallback(this, $A.getCallback(function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                if(response.getReturnValue()) hdl.getFiles(cmp);
                hdl.updateLogFile(cmp, removeFiles, 'Remove file', cmp.get('v.recordFolderId'));
                hdl.showToast(cmp, null, null, 'Removal complete!', 'info', 'File removal successful.');
            } else if (state === "ERROR") {
                var errors = response.getError();
                console.error(errors);
            }
        }));
        $A.enqueueAction(action);
    },
    
    
    updateLogFile: function(cmp, newFiles, actions, folderId) {
        var action = cmp.get('c.updateLog');
        action.setParams({
            'newFiles' : JSON.stringify(newFiles),
            'action' : actions,
            'recordId' : cmp.get('v.recordId'),
            'folderId' : folderId
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                //console.log(response.getReturnValue());
            } else if (state === "ERROR") {
                var errors = response.getError();
                console.error(errors);
            }
        });
        $A.enqueueAction(action);
    },
    
    
    showToast : function(component, event, helper, title, type, message) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": title,
            "message": message,
            "duration": 30000,
            "type": type
        });
        toastEvent.fire();
    },
    
    
    returnFileSize : function(number) {
        if(number < 1024) {
            return number + ' bytes';
        } else if(number > 1024 && number < 1048576) {
            return (number/1024).toFixed(1) + ' KB';
        } else if(number > 1048576) {
            return (number/1048576).toFixed(1) + ' MB';
        }
    }
})