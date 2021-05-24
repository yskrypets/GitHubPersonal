({
	init: function (component, event, helper) {
        var sPageURL = decodeURIComponent(window.location.search.substring(1));
        var sURLVariables = sPageURL.split('&');
        var sParameterName;
        var i;
        var redirect_url = '';
        var code = '';

        for (i = 0; i < sURLVariables.length; i++) {
            sParameterName = sURLVariables[i].split('=');

            if (sParameterName[0] === 'state') {
                redirect_url = sParameterName[1];
            }
            if (sParameterName[0] === 'code') {
                code = '?code=' + sParameterName[1];
            }
        }
        window.location.href = redirect_url + code;
    }
})