'use strict';

angular.module('myApp.home', ['ngRoute', 'ui.bootstrap'])

.config(['$routeProvider', function($routeProvider) {
    $routeProvider.when('/home', {
        templateUrl: 'views/home.html',
        controller: 'HomeCtrl'
    });
}])

.controller('HomeCtrl', ['$scope', '$http', '$timeout', '$modal', function($scope, $http, $timeout, $modal) {

    $scope.data = {
        item: { itemId: "", comment: "", category: "" },
        items: null,
        comments: null,
        isedit: false
    };

    $scope.loadData = function() {
        myUtils.showPleaseWait();
        $http.get(globalAPIURLPrefix + '/api/todo').success(function(data) {
            $scope.data.items = data;
        }).finally(function(data) {
            myUtils.hidePleaseWait();
        });
    };

    $scope.addItem = function(item) {
        $http.post(globalAPIURLPrefix + '/api/todo', item).success(function(data) {}).finally(function(data) {
            $scope.loadData();
            $scope.data.item = { comment: "", category: "" };
        });
    };

    $scope.editItem = function(item) {
        $scope.data.isedit = true;
        $scope.data.item = item;
    };

    $scope.editItemSave = function(item) {
        $http.put(globalAPIURLPrefix + '/api/todo/' + item.itemId, item).success(function(data) {}).finally(function(data) {
            $scope.data.isedit = false;
            $scope.data.item = { comment: "", category: "" };
            $scope.loadData();
        });
    };

    $scope.editItemCancel = function(item) {
        $scope.data.isedit = false;
        $scope.data.item = { comment: "", category: "" };
    };

    $scope.loadData();

}]);