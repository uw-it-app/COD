(function () {
    'use strict';

$(function () {

    // Datasource locations
    COD.dataSources = {
        "items": "/daw/json/COD/v2/Items"
    };

    // Namespace for JSON data
    COD.data = {};

    // RESTDatasource Error Handler
    COD.RESTErrorHandler = function(XMLHttpRequest, textStatus, errorThrown) {
        logger.debug(errorThrown);
    };

    // REST DataSources
    COD.REST = {};
    COD.REST.items = new RESTDataSource(COD.dataSources.items, COD.RESTErrorHandler);
    
    
    COD.itemsload = function(data){
        data.Items.Item = badgerArray(data.Items.Item);
        var count = data.Items.Item.length;
        for (var i = 0; i < 1; i++) {
            data.Items.Item[i].Escalations.Escalation = badgerArray(data.Items.Item[i].Escalations.Escalation);
        }
        COD.data.items = data;
        $('.items_bind').jpop(COD.data.items, {});
    }
    
    COD.start = function(){
        COD.REST.items.get({}, COD.itemsload, null);
    }
    COD.start();
});
}());


