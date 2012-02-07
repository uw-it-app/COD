<?php include('info.php'); ?>
<!DOCTYPE html>
<html lang="en">
    <meta charset="utf-8"/>
    <title>COD: Computer Operations Dashboard</title>
<?php include('css.php'); ?>
    <body>
        <div id="tools-container">
            <div id="tools-content">
<!-- Local HTML -->

<table id="itemsTable" class="full">
    <thead>
        <tr>
            <th class="">State</th>
            <th class="">ITIL Type</th>
            <th class="">Subject</th>
            <th class="">RT Ticket</th>
            <th class="hm_issue">H&amp;M Issue</th>
            <th class="ref_no">Ref No</th>
            <th class="">Model</th>
            <th class="">Severity</th>
            <th class="">Escalations</th>
            <th class="">Modified</th>
        </tr>
    </thead>
    <tbody class="items_bind" id="Items:Item">
        <tr class="clickable">
            <td class="items_bind" id="Item.State"></td>
            <td class="items_bind" id="Item.ITILType"></td>
            <td class="items_bind" id="Item.Subject"></td>
            <td class="items_bind" id="Item.RTTicket"></td>
            <td class="items_bind hm_issue" id="Item.HMIssue"></td>
            <td class="items_bind ref_no" id="Item.ReferenceNumber"></td>
            <td class="items_bind" id="Item.SupportModel"></td>
            <td class="items_bind" id="Item.Severity"></td>
            <td>
                <table class="full">
                    <tr>
                        <th class="">Oncall</th>
                        <th class="">RT</th>
                        <th class="">H&amp;M</th>
                    </tr>
                <tbody class="items_bind" id="Item.Escalations:Escalation">
                    <tr>
                        <td class="items_bind" id="Escalation.OncallGroup"></td>
                        <td class="items_bind" id="Escalation.RTTicket"></td>
                        <td class="items_bind" id="Escalation.HMIssue"></td>
                    </tr>
                </tbody>
                </table>
            </td>
            <td class="items_bind" id="Item.Modified.At"></td>
        </tr>
    </tbody>
</table>

<!-- End Local HTML -->
            </div>
        <!-- end #tools-content -->
        </div>
        <!-- end #tools-container -->
<!-- Start Script block -->
<?php include('js.php'); ?>
        <script src="/.cod/js/ui.items.js"></script>
        <script>
            var toolsBreadcrumbs = [
                {title: 'SSG', href: '/'},
                {title: 'COD', href: '/.cod/'}
            ];
            $(document).ready( function() {
                $('#itemsTable').items();
                // stylize all the buttons with jQueryUI
                $("button, input[type=image], input[type=submit], input[type=reset], input[type=button]").button();
            });
        </script>
<!-- End Script block -->
    </body>
</html>
