$(document).ready(function($) {
  $('#frontend').on('change', function() {
    if ($(this).val() == 'native') {
      $('#api_protocol').removeAttr('disabled');
    } else {
      if ($('#api_protocol').val() == 'https') {
        $('#api_protocol').val('http').trigger('change');
      }

      $('#api_protocol').attr('disabled', 'disabled');
    }
  }).trigger('change');
});
