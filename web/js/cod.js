/*jslint nomen: true, regexp: true */
/*global $ */
/*global logger */
/*global RESTDataSource */
/*global badgerArray */
/*global location */
/*global moment*/
/*global document*/
var COD = {},
    toolsAppName = {title: 'COD', href: './'};

(function () {
    'use strict';

    // Datasource locations
    COD.dataSources = {
        "items": "/daw/json/COD/v2/Items",
        "item": "/daw/json/COD/v2/Item"
    };

    // Namespace for JSON data
    COD.data = {};

    // RESTDatasource Error Handler
    COD.RESTErrorHandler = function (XMLHttpRequest, textStatus, errorThrown) {
        logger.debug(errorThrown);
        if (XMLHttpRequest.status == 401) {
            window.location = '/norns/?path=' + escape(window.location.pathname);
        }
    };

    // REST DataSources
    COD.REST = {};

    // Refresh ID namespace
    COD.rid = {};

    COD.createLastUpdated = function () {
        $('#tools-app-title-bar-right').append('<div id="last-updated">Last Updated: <span id="last-updated-time">____-__-__ __:__:__</span></div>');
    };

    COD.updateLastUpdated = function () {
        $('#last-updated-time').html(moment().format('YYYY-MM-DD HH:mm:ss'))
                .animate({backgroundColor:'#EDE'},500).delay(500).animate({backgroundColor:'#FFF'}, 500);
    };

    COD.rtLinker = function () {
        $('a.rtlink').each(function () {
            var value = $(this).text();
            $(this).attr({href:'https://rt.cac.washington.edu/Ticket/Display.html?id='+value});
        });
    };

    COD.hmLinker = function () {
        $('a.hmlink').each(function () {
            var value = $(this).text();
            $(this).attr({href:'/hm/view/issue/'+value});
        });
    };

    COD.linker = function () {
        $(document).on('click', 'a.rtlink, a.hmlink', function () {
            window.open($(this).attr('href'));
            false;
        })
    }
}());


