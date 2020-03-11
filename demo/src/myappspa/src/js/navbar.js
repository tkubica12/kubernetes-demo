function setPageState(pageState) {
    $("#navHome").attr('class', '');
    $("#navSystem").attr('class', '');

    if (pageState == "HOME") {
        $("#navHome").attr('class', 'active');
    } else if (pageState == "SYSTEM") {
        $("#navSystem").attr('class', 'active');
    }
}

function _showNavBar() {
    var _url = window.location.href.trim();
    if (_url.indexOf("#") > 0) {
        _url = _url.split("#")[1];
    }
    switch (_url) {
        case "/home":
            setPageState("HOME");
            break;
        case "/about":
            setPageState("SYSTEM");
            break;
    }

    $("#navVersionA").text(globalInstanceName + " - " + globalInstanceVersion);
}

$(document).ready(function() {
    setTimeout(_showNavBar, 200);
});