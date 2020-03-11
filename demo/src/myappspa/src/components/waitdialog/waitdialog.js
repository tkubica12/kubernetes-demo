var myUtils;
myUtils = myUtils || (function () {
        return {
            showPleaseWait: function() {
                $("#pleaseWaitDialog").modal();
            },
            hidePleaseWait: function () {
                $("#pleaseWaitDialog").modal('hide');
            },
            showSystemUpdated: function () {
                lblSystemUpdatedMain
                $("#lblSystemUpdatedMain").text("System update");
                $("#lblSystemUpdated").text("System successfully updated. Page will be reloaded in few seconds.");
                $("#dlgSystemUpdated").modal();
            },
            showSystemUpdatedMessage: function (_msg) {
                $("#lblSystemUpdatedMain").text("System update");
                $("#lblSystemUpdated").text(_msg);
                $("#dlgSystemUpdated").modal();
            },
            hideSystemUpdated: function () {
                $("#dlgSystemUpdated").modal('hide');
            },
            showMyMessage: function (_header, _msg) {
                $("#lblSystemUpdatedMain").text(_header);
                $("#lblSystemUpdated").text(_msg);
                $("#dlgSystemUpdated").modal();
            },
            hideMyMessage: function () {
                $("#dlgSystemUpdated").modal('hide');
            },
        };
    })();
