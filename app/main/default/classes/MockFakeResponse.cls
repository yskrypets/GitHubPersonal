@isTest
global class MockFakeResponse implements HttpCalloutMock {
    Boolean withFiles = false;
    
    global MockFakeResponse() {
        this.withFiles = false;
    }
    
    global MockFakeResponse(Boolean withFiles) {
        this.withFiles = withFiles;
    }
    
    global HTTPResponse respond(HTTPRequest req) {
        if(req.getEndpoint() == 'https://accounts.google.com/o/oauth2/token') {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"access_token":"testaccesstoken","refresh_token":"testrefreshtoken"}');
            res.setStatusCode(200);
            System.assertEquals(200, res.GetStatusCode());
            return res;
        } else if(req.getEndpoint() == 'https://content.googleapis.com/drive/v2/files') {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"id":"testid"}');
            res.setStatusCode(200);
            System.assertEquals(200, res.GetStatusCode());
            return res;
        } else if(req.getEndpoint().startsWith('https://content.googleapis.com/drive/v3/files')) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if(withFiles) {
                res.setBody('{"id":"testid","files":[{"id":"testid","title":"test.txt","description":"001000000000000","mimeType":"text/plain","iconLink":"a.com","fileSize":"1","webContentLink":"b.com"}]}');
            } else {
                res.setBody('{"id":"testid","files":[]}');
            }
            res.setStatusCode(200);
            System.assertEquals(200, res.GetStatusCode());
            return res;
        } else if(req.getEndpoint().startsWith('https://www.googleapis.com/oauth2/v1/tokeninfo')) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"expires_in":100}');
            res.setStatusCode(200);
            System.assertEquals(200, res.GetStatusCode());
            return res;
        } else if(req.getEndpoint().startsWith('https://www.googleapis.com/oauth2/v4/token')) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"access_token":"testaccesstoken"}');
            res.setStatusCode(200);
            System.assertEquals(200, res.GetStatusCode());
            return res;
        } else if(req.getEndpoint().startsWith('https://content.googleapis.com/drive/v2/files')) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if(withFiles) {
                res.setBody('{"id":"testid","items":[{"id":"testid","title":"test","description":"001000000000000","mimeType":"text/plain","iconLink":"a.com","fileSize":"1","webContentLink":"b.com","parents":[{"id":"testparentId"}],"properties":[{"key":"subfolder","value":"subfolder"}]}]}');
            } else {
                res.setBody('{"id":"testid","items":[]}');
            }
            res.setStatusCode(200);
            System.assertEquals(200, res.GetStatusCode());
            return res;
        } else if(req.getEndpoint().startsWith('https://graph.microsoft.com/v1.0/me/drive/items/')) {
            system.debug(req.getEndpoint());
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if(withFiles) {
                res.setBody('{"id":"testid","address":"1:1234","value":[{"file":{"mimeType":"text/plain"},"id":"testid","name":"test","description":"001000000000000","iconLink":"Log.xlsx","fileSize":"1","webContentLink":"b.com","parentReference":{"id":"testparentId","name":"test","path":"a/b"},"properties":[{"key":"subfolder","value":"subfolder"}]}]}');
            } else {
                res.setBody('{"id":"testid","value":[]}');
            }
            res.setStatusCode(200);
            System.assertEquals(200, res.GetStatusCode());
            return res;
        } else if(req.getEndpoint().startsWith('https://graph.microsoft.com/v1.0/me/drive/root/children')) {
            system.debug(req.getEndpoint());
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if(withFiles) {
                res.setBody('{"id":"testid","value":[{"file":{"mimeType":"text/plain"},"id":"testid","name":"test","description":"001000000000000","iconLink":"a.com","fileSize":"1","webContentLink":"b.com","parentReference":{"id":"testparentId","name":"test","path":"a/b"},"properties":[{"key":"subfolder","value":"subfolder"}]}]}');
            } else {
                res.setBody('{"id":"testid","value":[]}');
            }
            res.setStatusCode(200);
            System.assertEquals(200, res.GetStatusCode());
            return res;
        } else if(req.getEndpoint().startsWith('https://graph.microsoft.com/v1.0/me/drive/root/search')) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if(withFiles) {
                res.setBody('{"id":"testid","value":[{"id":"testid","name":"test","description":"001000000000000","mimeType":"text/plain","iconLink":"a.com","fileSize":"1","webContentLink":"b.com","parentReference":{"id":"testparentId","path":"a/b"},"properties":[{"key":"subfolder","value":"subfolder"}]}]}');
            } else {
                res.setBody('{"id":"testid","value":[]}');
            }
            res.setStatusCode(200);
            System.assertEquals(200, res.GetStatusCode());
            return res;
        } else if(req.getEndpoint().startsWith('https://www.googleapis.com/drive/v2/files')) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"id":"testid","title":"test","items":[{"id":"testid","title":"test.txt","description":"001000000000000","mimeType":"text/plain","iconLink":"a.com","fileSize":"1","webContentLink":"b.com"}],"parents":[{"id":"testid"}],"properties":[{"key":"subfolder","value":"subfolder"}]}');
            res.setStatusCode(200);
            System.assertEquals(200, res.GetStatusCode());
            return res;
        } else if(req.getEndpoint().startsWith('https://www.googleapis.com/drive/v3/files')) {
            HttpResponse res = new HttpResponse();
            res.setBodyAsBlob(Blob.valueOf('test content'));
            res.setStatusCode(200);
            System.assertEquals(200, res.GetStatusCode());
            return res;
        } else if(req.getEndpoint().startsWith('https://www.googleapis.com/upload/drive/v3/files')) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"sfId":"testid"}');
            res.setStatusCode(200);
            System.assertEquals(200, res.GetStatusCode());
            return res;
        } else if(req.getEndpoint().startsWith(System.Url.getSalesforceBaseURL().toExternalForm())) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{}');
            res.setStatusCode(200);
            System.assertEquals(200, res.GetStatusCode());
            return res;
        }
        
        return new HttpResponse();
    }
}