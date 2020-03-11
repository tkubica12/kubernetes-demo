'use strict';

var globalAPIURLPrefix = "#TODOAPIURL#";
var globalInstanceName = "#INSTANCENAME#";
var globalInstanceVersion = "#INSTANCEVERSION#";

// Declare app level module which depends on views, and components
angular.module('myApp', [
    'ngRoute',
    'myApp.home',
    'myApp.about'
]).
config(['$routeProvider', function($routeProvider) {
    $routeProvider.otherwise({ redirectTo: '/home' });
}]).
factory('alertService', function($rootScope) {
    var alertService = {};

    // create an array of alerts available globally
    $rootScope.alerts = [];

    alertService.add = function(type, msg) {
        for (var i = 0; i < $rootScope.alerts.length; i++) {
            if ($rootScope.alerts[i].type == type) {
                return;
            }
        }
        $rootScope.alerts.push({ 'type': type, 'msg': msg });
    };

    alertService.clear = function(type) {
        for (var i = 0; i < $rootScope.alerts.length; i++) {
            if ($rootScope.alerts[i].type == type) {
                $rootScope.alerts.splice(i, 1);
            }
        }
    };

    return alertService;
});