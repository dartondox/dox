import 'package:dox_core/validation/dox_validator.dart';
import 'package:test/test.dart';

void main() {
  group('Validation |', () {
    test('required on null with dot', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{
        'user': <String, dynamic>{'name': null}
      });
      validator.validate(<String, String>{'user.name': 'required'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['user.name'], 'The name is required');
    });

    test('required on null', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'email': null});
      validator.validate(<String, String>{'email': 'required'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['email'], 'The email is required');
    });

    test('required on empty', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'email': ''});
      validator.validate(<String, String>{'email': 'required'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['email'], 'The email is required');
    });

    test('should not be error', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'email': 'support@dartondox.dev'});
      validator.validate(<String, String>{'email': 'required'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['email'], null);
    });

    test('invalid email', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'email': 'invalid'});
      validator.validate(<String, String>{'email': 'required|email'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['email'], 'The email is not a valid email');
    });

    test('valid email', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'email': 'support@dartondox.dev'});
      validator.validate(<String, String>{'email': 'required|email'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['email'], null);
    });

    test('numeric string', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'age': '1'});
      validator.validate(<String, String>{'age': 'numeric'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['age'], null);
    });

    test('numeric number', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'age': 1});
      validator.validate(<String, String>{'age': 'numeric'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['age'], null);
    });

    test('not numeric number should throw error', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'age': 'abcd'});
      validator.validate(<String, String>{'age': 'numeric'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['age'], 'The age must be a number');
    });

    test('non alpha number', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'name': '1'});
      validator.validate(<String, String>{'name': 'alpha'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['name'], 'The name must be an alphabetic');
    });

    test('non alpha string', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'name': 'dox'});
      validator.validate(<String, String>{'name': 'alpha'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['name'], null);
    });

    test('non alpha with numeric', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'name': 'dox1'});
      validator.validate(<String, String>{'name': 'alpha'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['name'], 'The name must be an alphabetic');
    });

    test('alpha_dash', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'name': 'dox_web-framework'});
      validator.validate(<String, String>{'name': 'alpha_dash'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['name'], null);
    });

    test('non alpha_dash (symbol)', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'name': '&&s'});
      validator.validate(<String, String>{'name': 'alpha_dash'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['name'], 'The name must be only alphabetic and dash');
    });

    test('non alpha_dash (number)', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'name': 1});
      validator.validate(<String, String>{'name': 'alpha_dash'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['name'], 'The name must be only alphabetic and dash');
    });

    test('non ip', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'ip': 'abcd'});
      validator.validate(<String, String>{'ip': 'ip'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['ip'], 'The ip must be an ip address');
    });

    test('ip', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'ip': '192.168.1.1'});
      validator.validate(<String, String>{'ip': 'ip'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['ip'], null);
    });

    test('boolean', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'active': true});
      validator.validate(<String, String>{'active': 'boolean'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['active'], null);
    });

    test('non boolean', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'active': 'true'});
      validator.validate(<String, String>{'active': 'boolean'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['active'], 'The active must be a boolean');
    });

    test('integer string', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'age': '10'});
      validator.validate(<String, String>{'age': 'integer'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['age'], null);
    });

    test('integer', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'age': 10});
      validator.validate(<String, String>{'age': 'integer'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['age'], null);
    });

    test('non integer', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'age': '10.2'});
      validator.validate(<String, String>{'age': 'integer'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['age'], 'The age must be an integer');
    });

    test('non double', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'amount': 'double'});
      validator.validate(<String, String>{'amount': 'double'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['amount'], 'The amount must be a double');
    });

    test('double', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'amount': '10.2'});
      validator.validate(<String, String>{'amount': 'double'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['amount'], null);
    });

    test('array', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{
        'list': <String>['1', '2']
      });
      validator.validate(<String, String>{'list': 'array'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['list'], null);
    });

    test('non array', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'list': 'this is a string'});
      validator.validate(<String, String>{'list': 'array'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['list'], 'The list must be an array');
    });

    test('in', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'status': 'active'});
      validator.validate(<String, String>{'status': 'in:active,pending'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['status'], null);
    });

    test('invalid in', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'status': 'failed'});
      validator.validate(<String, String>{'status': 'in:active,pending'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['status'],
          'The selected status is invalid. Valid options are active, and pending');
    });

    test('not_in', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'status': 'failed'});
      validator.validate(<String, String>{'status': 'not_in:active,pending'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['status'], null);
    });

    test('invalid not_in', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'status': 'active'});
      validator.validate(<String, String>{'status': 'not_in:active,pending'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['status'], 'The status field cannot be active');
    });

    test('date', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'dob': '1994-11-22'});
      validator.validate(<String, String>{'dob': 'date'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['dob'], null);
    });

    test('invalid date', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'dob': '1994/11/22'});
      validator.validate(<String, String>{'dob': 'date'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['dob'], 'The dob must be a date');
    });

    test('map', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{
        'info': <String, String>{'name': 'dox'}
      });
      validator.validate(<String, String>{'info': 'json'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['info'], null);
    });

    test('not map', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'info': 'user info'});
      validator.validate(<String, String>{'info': 'json'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['info'], 'The info is not a valid json');
    });

    test('map with dot', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{
        'info': <String, String>{'name': 'dox', 'email': ''}
      });
      validator.validate(<String, String>{
        'info.name': 'required|string',
        'info.email': 'required|email',
      });
      Map<String, dynamic> errors = validator.errors;
      expect(errors['info.name'], null);
      expect(errors['info.email'], 'The email is required');
    });

    test('invalid url', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'url': 'just string'});
      validator.validate(<String, String>{'url': 'url'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['url'], 'The url must be a url');
    });

    test('url', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'url': 'https://dartondox.dev'});
      validator.validate(<String, String>{'url': 'url'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['url'], null);
    });

    test('invalid uuid', () {
      DoxValidator validator =
          DoxValidator(<String, dynamic>{'uuid': 'just string'});
      validator.validate(<String, String>{'uuid': 'uuid'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['uuid'], 'The uuid is invalid uuid');
    });

    test('uuid', () {
      DoxValidator validator = DoxValidator(
          <String, dynamic>{'uuid': '30aa26a1-04f4-481e-80d1-59fdb4b9fdf5'});
      validator.validate(<String, String>{'uuid': 'uuid'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['uuid'], null);
    });

    test('invalid min_length', () {
      DoxValidator validator = DoxValidator(
          <String, dynamic>{'uuid': '30aa26a1-04f4-481e-80d1-59fdb4b9fdf5'});
      validator.validate(<String, String>{'uuid': 'min_length:50'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['uuid'], 'The uuid must be at least 50 character');
    });

    test('min_length', () {
      DoxValidator validator = DoxValidator(
          <String, dynamic>{'uuid': '30aa26a1-04f4-481e-80d1-59fdb4b9fdf5'});
      validator.validate(<String, String>{'uuid': 'min_length:10'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['uuid'], null);
    });

    test('invalid max_length', () {
      DoxValidator validator = DoxValidator(
          <String, dynamic>{'uuid': '30aa26a1-04f4-481e-80d1-59fdb4b9fdf5'});
      validator.validate(<String, String>{'uuid': 'max_length:10'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['uuid'], 'The uuid may not be greater than 10 character');
    });

    test('max_length', () {
      DoxValidator validator = DoxValidator(
          <String, dynamic>{'uuid': '30aa26a1-04f4-481e-80d1-59fdb4b9fdf5'});
      validator.validate(<String, String>{'uuid': 'max_length:50'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['uuid'], null);
    });

    test('invalid length between', () {
      DoxValidator validator = DoxValidator(
          <String, dynamic>{'uuid': '30aa26a1-04f4-481e-80d1-59fdb4b9fdf5'});
      validator.validate(<String, String>{'uuid': 'length_between:10,15'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['uuid'], 'The uuid must be between 10 and 15 character');
    });

    test('length between', () {
      DoxValidator validator = DoxValidator(
          <String, dynamic>{'uuid': '30aa26a1-04f4-481e-80d1-59fdb4b9fdf5'});
      validator.validate(<String, String>{'uuid': 'length_between:10,50'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['uuid'], null);
    });

    test('invalid min value', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'age': '1'});
      validator.validate(<String, String>{'age': 'min:10'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['age'], 'The age must be greater than or equal 10');
    });

    test('min value', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'age': '10'});
      validator.validate(<String, String>{'age': 'min:10'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['age'], null);
    });

    test('invalid max value', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'age': '11'});
      validator.validate(<String, String>{'age': 'max:10'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['age'], 'The age must be less than or equal 10');
    });

    test('max value', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'age': '7'});
      validator.validate(<String, String>{'age': 'max:10'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['age'], null);
    });

    test('invalid greater than', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'age': '6'});
      validator.validate(<String, String>{'age': 'greater_than:10'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['age'], 'The age must be greater than 10');
    });

    test('greater than', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'age': '11'});
      validator.validate(<String, String>{'age': 'greater_than:10'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['age'], null);
    });

    test('invalid less than', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'age': '11'});
      validator.validate(<String, String>{'age': 'less_than:10'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['age'], 'The age must be less than 10');
    });

    test('less than', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'age': '7'});
      validator.validate(<String, String>{'age': 'less_than:10'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['age'], null);
    });

    test('invalid start with', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'name': 'dox'});
      validator.validate(<String, String>{'name': 'start_with:dart'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['name'], 'The name must start with dart');
    });

    test('start with', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'name': 'dox'});
      validator.validate(<String, String>{'name': 'start_with:do'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['name'], null);
    });

    test('invalid end with', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'name': 'dox'});
      validator.validate(<String, String>{'name': 'end_with:dart'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['name'], 'The name must end with dart');
    });

    test('end with', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{'name': 'dox'});
      validator.validate(<String, String>{'name': 'end_with:x'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['name'], null);
    });

    test('invalid confirmed', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{
        'password': '12345678',
        'password_confirmation': '12345878',
      });
      validator.validate(<String, String>{'password': 'confirmed'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['password'], 'The two password did not match');
    });

    test('invalid confirmed 2', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{
        'password': '12345678',
        'password_confirmation': '12345678',
      });
      validator.validate(<String, String>{'password': 'confirmed'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['password'], null);
    });

    test('invalid confirmed', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{
        'password': '12345678',
        'password_confirm': '12345678',
      });
      validator
          .validate(<String, String>{'password': 'confirmed:password_confirm'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['password'], null);
    });

    test('invalid required if', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{
        'dob': '',
        'type': 'register',
      });
      validator.validate(<String, String>{'dob': 'required_if:type,register'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['dob'], 'The dob is required');
    });

    test('required if', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{
        'dob': '',
        'type': 'login',
      });
      validator.validate(<String, String>{'dob': 'required_if:type,register'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['dob'], null);
    });

    test('required if 2', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{
        'dob': '1994-22-11',
        'type': 'register',
      });
      validator.validate(<String, String>{'dob': 'required_if:type,register'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['dob'], null);
    });

    test('invalid required if not', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{
        'dob': '',
        'type': 'register',
      });
      validator.validate(<String, String>{'dob': 'required_if_not:type,login'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['dob'], 'The dob is required');
    });

    test('required if not', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{
        'dob': '',
        'type': 'login',
      });
      validator.validate(<String, String>{'dob': 'required_if_not:type,login'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['dob'], null);
    });

    test('required if not 2', () {
      DoxValidator validator = DoxValidator(<String, dynamic>{
        'dob': '1994-22-11',
        'type': 'register',
      });
      validator.validate(<String, String>{'dob': 'required_if_not:type,login'});
      Map<String, dynamic> errors = validator.errors;
      expect(errors['dob'], null);
    });

    test('with dots', () {
      Map<String, dynamic> data = <String, dynamic>{
        'products': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'iphone',
            'items': <Map<String, String>>[
              <String, String>{'title': ''},
              <String, String>{'title': 'case'},
            ]
          },
          <String, dynamic>{
            'name': '',
            'items': <Map<String, String>>[
              <String, String>{'title': 'cable'},
              <String, String>{'title': ''},
            ]
          }
        ],
      };
      DoxValidator validator = DoxValidator(data);
      validator.validate(<String, String>{
        'products.*.items.*.title': 'required',
        'products.*.name': 'required',
      });
      Map<String, String> errors = validator.errors;
      expect(errors['products.0.items.0.title'], 'The title is required');
      expect(errors['products.1.items.1.title'], 'The title is required');
      expect(errors['products.1.name'], 'The name is required');
      expect(errors.length, 3);
    });
  });
}
