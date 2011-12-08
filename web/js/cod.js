/*jslint nomen: true, regexp: true */
/*global $ */
/*global logger */
/*global RESTDataSource */
/*global badgerArray */
(function () {
    'use strict';
    $(function () {

        var COD = {};

        // Datasource locations
        COD.dataSources = {
            "items": "/daw/json/COD/v2/Items"
        };

        // Namespace for JSON data
        COD.data = {};

        // RESTDatasource Error Handler
        COD.RESTErrorHandler = function (XMLHttpRequest, textStatus, errorThrown) {
            logger.debug(errorThrown);
        };

        // REST DataSources
        COD.REST = {};
        COD.REST.items = new RESTDataSource(COD.dataSources.items, COD.RESTErrorHandler);

        COD.itemsload = function (data) {
            var count, i;
            data.Items.Item = badgerArray(data.Items.Item);
            count = data.Items.Item.length;
            for (i = 0; i < count; i = i + 1) {
                data.Items.Item[i].Escalations.Escalation = badgerArray(data.Items.Item[i].Escalations.Escalation);
            }
            COD.data.items = data;
            $('.items_bind').jpop(COD.data.items, {});
        };

        COD.start = function () {
            COD.REST.items.get({}, COD.itemsload, null);
        };

        COD.start();
    });
}());


