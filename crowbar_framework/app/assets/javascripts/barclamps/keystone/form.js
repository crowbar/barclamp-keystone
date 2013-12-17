$(document).ready(function($) {
  $('#ssl_generate_certs').on('change', function() {
    var $parent = $('#ssl_certfile, #ssl_keyfile, #ssl_insecure');

    if ($(this).val() == 'true') {
      $parent.attr('disabled', 'disabled');

      $('#ssl_certfile').val('/etc/keystone/ssl/certs/signing_cert.pem');
      $('#ssl_keyfile').val('/etc/keystone/ssl/private/signing_key.pem');
      $('#ssl_insecure').val('true');
    } else {
      $parent.removeAttr('disabled');
    }
  }).trigger('change');
});
