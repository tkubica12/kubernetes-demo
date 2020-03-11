'use strict';

angular.module('myApp.about', ['ngRoute'])

.config(['$routeProvider', function($routeProvider) {
    $routeProvider.when('/about', {
        templateUrl: 'views/about.html',
        controller: 'AboutCtrl'
    });
}])

.controller('AboutCtrl', ['$scope', '$http', function($scope, $http) {

}]);