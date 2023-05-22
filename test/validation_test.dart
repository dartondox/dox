import 'package:dox_core/validation/dox_validator.dart';
import 'package:test/test.dart';

void main() {
  group('Validation |', () {
    test('required on null with dot', () {
      var validator = DoxValidator({
        'user': {'name': null}
      });
      validator.validate({"user.name": 'required'});
      var errors = validator.getErrors();
      expect(errors['user.name'], 'The name is required');
    });

    test('required on null', () {
      var validator = DoxValidator({'email': null});
      validator.validate({"email": 'required'});
      var errors = validator.getErrors();
      expect(errors['email'], 'The email is required');
    });

    test('required on empty', () {
      var validator = DoxValidator({'email': ''});
      validator.validate({"email": 'required'});
      var errors = validator.getErrors();
      expect(errors['email'], 'The email is required');
    });

    test('should not be error', () {
      var validator = DoxValidator({'email': 'support@dartondox.dev'});
      validator.validate({"email": 'required'});
      var errors = validator.getErrors();
      expect(errors['email'], null);
    });

    test('invalid email', () {
      var validator = DoxValidator({'email': 'invalid'});
      validator.validate({"email": 'required|email'});
      var errors = validator.getErrors();
      expect(errors['email'], 'The email is not a valid email');
    });

    test('valid email', () {
      var validator = DoxValidator({'email': 'support@dartondox.dev'});
      validator.validate({"email": 'required|email'});
      var errors = validator.getErrors();
      expect(errors['email'], null);
    });

    test('numeric string', () {
      var validator = DoxValidator({'age': '1'});
      validator.validate({"age": 'numeric'});
      var errors = validator.getErrors();
      expect(errors['age'], null);
    });

    test('numeric number', () {
      var validator = DoxValidator({'age': 1});
      validator.validate({"age": 'numeric'});
      var errors = validator.getErrors();
      expect(errors['age'], null);
    });

    test('not numeric number should throw error', () {
      var validator = DoxValidator({'age': 'abcd'});
      validator.validate({"age": 'numeric'});
      var errors = validator.getErrors();
      expect(errors['age'], 'The age must be a number');
    });

    test('non alpha number', () {
      var validator = DoxValidator({'name': '1'});
      validator.validate({"name": 'alpha'});
      var errors = validator.getErrors();
      expect(errors['name'], 'The name must be an alphabetic');
    });

    test('non alpha string', () {
      var validator = DoxValidator({'name': 'dox'});
      validator.validate({"name": 'alpha'});
      var errors = validator.getErrors();
      expect(errors['name'], null);
    });

    test('non alpha with numeric', () {
      var validator = DoxValidator({'name': 'dox1'});
      validator.validate({"name": 'alpha'});
      var errors = validator.getErrors();
      expect(errors['name'], 'The name must be an alphabetic');
    });

    test('alpha_dash', () {
      var validator = DoxValidator({'name': 'dox_web-framework'});
      validator.validate({"name": 'alpha_dash'});
      var errors = validator.getErrors();
      expect(errors['name'], null);
    });

    test('non alpha_dash (symbol)', () {
      var validator = DoxValidator({'name': '&&s'});
      validator.validate({"name": 'alpha_dash'});
      var errors = validator.getErrors();
      expect(errors['name'], 'The name must be only alphabetic and dash');
    });

    test('non alpha_dash (number)', () {
      var validator = DoxValidator({'name': 1});
      validator.validate({"name": 'alpha_dash'});
      var errors = validator.getErrors();
      expect(errors['name'], 'The name must be only alphabetic and dash');
    });

    test('non ip', () {
      var validator = DoxValidator({'ip': 'abcd'});
      validator.validate({"ip": 'ip'});
      var errors = validator.getErrors();
      expect(errors['ip'], 'The ip must be an ip address');
    });

    test('ip', () {
      var validator = DoxValidator({'ip': '192.168.1.1'});
      validator.validate({"ip": 'ip'});
      var errors = validator.getErrors();
      expect(errors['ip'], null);
    });

    test('boolean', () {
      var validator = DoxValidator({'active': true});
      validator.validate({"active": 'boolean'});
      var errors = validator.getErrors();
      expect(errors['active'], null);
    });

    test('non boolean', () {
      var validator = DoxValidator({'active': 'true'});
      validator.validate({"active": 'boolean'});
      var errors = validator.getErrors();
      expect(errors['active'], 'The active must be a boolean');
    });

    test('integer string', () {
      var validator = DoxValidator({'age': '10'});
      validator.validate({"age": 'integer'});
      var errors = validator.getErrors();
      expect(errors['age'], null);
    });

    test('integer', () {
      var validator = DoxValidator({'age': 10});
      validator.validate({"age": 'integer'});
      var errors = validator.getErrors();
      expect(errors['age'], null);
    });

    test('non integer', () {
      var validator = DoxValidator({'age': '10.2'});
      validator.validate({"age": 'integer'});
      var errors = validator.getErrors();
      expect(errors['age'], 'The age must be an integer');
    });

    test('non double', () {
      var validator = DoxValidator({'amount': 'double'});
      validator.validate({"amount": 'double'});
      var errors = validator.getErrors();
      expect(errors['amount'], 'The amount must be a double');
    });

    test('double', () {
      var validator = DoxValidator({'amount': '10.2'});
      validator.validate({"amount": 'double'});
      var errors = validator.getErrors();
      expect(errors['amount'], null);
    });

    test('array', () {
      var validator = DoxValidator({
        'list': ['1', '2']
      });
      validator.validate({"list": 'array'});
      var errors = validator.getErrors();
      expect(errors['list'], null);
    });

    test('non array', () {
      var validator = DoxValidator({'list': 'this is a string'});
      validator.validate({"list": 'array'});
      var errors = validator.getErrors();
      expect(errors['list'], 'The list must be an array');
    });

    test('in', () {
      var validator = DoxValidator({'status': 'active'});
      validator.validate({"status": 'in:active,pending'});
      var errors = validator.getErrors();
      expect(errors['status'], null);
    });

    test('invalid in', () {
      var validator = DoxValidator({'status': 'failed'});
      validator.validate({"status": 'in:active,pending'});
      var errors = validator.getErrors();
      expect(errors['status'],
          'The selected status is invalid. Valid options are active, and pending');
    });

    test('not_in', () {
      var validator = DoxValidator({'status': 'failed'});
      validator.validate({"status": 'not_in:active,pending'});
      var errors = validator.getErrors();
      expect(errors['status'], null);
    });

    test('invalid not_in', () {
      var validator = DoxValidator({'status': 'active'});
      validator.validate({"status": 'not_in:active,pending'});
      var errors = validator.getErrors();
      expect(errors['status'], 'The status field cannot be active');
    });

    test('date', () {
      var validator = DoxValidator({'dob': '1994-11-22'});
      validator.validate({"dob": 'date'});
      var errors = validator.getErrors();
      expect(errors['dob'], null);
    });

    test('invalid date', () {
      var validator = DoxValidator({'dob': '1994/11/22'});
      validator.validate({"dob": 'date'});
      var errors = validator.getErrors();
      expect(errors['dob'], 'The dob must be a date');
    });

    test('map', () {
      var validator = DoxValidator({
        'info': {'name': 'dox'}
      });
      validator.validate({"info": 'json'});
      var errors = validator.getErrors();
      expect(errors['info'], null);
    });

    test('not map', () {
      var validator = DoxValidator({'info': 'user info'});
      validator.validate({"info": 'json'});
      var errors = validator.getErrors();
      expect(errors['info'], 'The info is not a valid json');
    });

    test('map with dot', () {
      var validator = DoxValidator({
        'info': {'name': 'dox', 'email': ''}
      });
      validator.validate({
        "info.name": 'required|string',
        "info.email": 'required|email',
      });
      var errors = validator.getErrors();
      expect(errors['info.name'], null);
      expect(errors['info.email'], 'The email is required');
    });

    test('invalid url', () {
      var validator = DoxValidator({'url': 'just string'});
      validator.validate({"url": 'url'});
      var errors = validator.getErrors();
      expect(errors['url'], 'The url must be a url');
    });

    test('url', () {
      var validator = DoxValidator({'url': 'https://dartondox.dev'});
      validator.validate({"url": 'url'});
      var errors = validator.getErrors();
      expect(errors['url'], null);
    });

    test('invalid uuid', () {
      var validator = DoxValidator({'uuid': 'just string'});
      validator.validate({"uuid": 'uuid'});
      var errors = validator.getErrors();
      expect(errors['uuid'], 'The uuid is invalid uuid');
    });

    test('uuid', () {
      var validator =
          DoxValidator({'uuid': '30aa26a1-04f4-481e-80d1-59fdb4b9fdf5'});
      validator.validate({"uuid": 'uuid'});
      var errors = validator.getErrors();
      expect(errors['uuid'], null);
    });

    test('invalid min_length', () {
      var validator =
          DoxValidator({'uuid': '30aa26a1-04f4-481e-80d1-59fdb4b9fdf5'});
      validator.validate({"uuid": 'min_length:50'});
      var errors = validator.getErrors();
      expect(errors['uuid'], 'The uuid must be at least 50 character');
    });

    test('min_length', () {
      var validator =
          DoxValidator({'uuid': '30aa26a1-04f4-481e-80d1-59fdb4b9fdf5'});
      validator.validate({"uuid": 'min_length:10'});
      var errors = validator.getErrors();
      expect(errors['uuid'], null);
    });

    test('invalid max_length', () {
      var validator =
          DoxValidator({'uuid': '30aa26a1-04f4-481e-80d1-59fdb4b9fdf5'});
      validator.validate({"uuid": 'max_length:10'});
      var errors = validator.getErrors();
      expect(errors['uuid'], 'The uuid may not be greater than 10 character');
    });

    test('max_length', () {
      var validator =
          DoxValidator({'uuid': '30aa26a1-04f4-481e-80d1-59fdb4b9fdf5'});
      validator.validate({"uuid": 'max_length:50'});
      var errors = validator.getErrors();
      expect(errors['uuid'], null);
    });

    test('invalid length between', () {
      var validator =
          DoxValidator({'uuid': '30aa26a1-04f4-481e-80d1-59fdb4b9fdf5'});
      validator.validate({"uuid": 'length_between:10,15'});
      var errors = validator.getErrors();
      expect(errors['uuid'], 'The uuid must be between 10 and 15 character');
    });

    test('length between', () {
      var validator =
          DoxValidator({'uuid': '30aa26a1-04f4-481e-80d1-59fdb4b9fdf5'});
      validator.validate({"uuid": 'length_between:10,50'});
      var errors = validator.getErrors();
      expect(errors['uuid'], null);
    });

    test('invalid min value', () {
      var validator = DoxValidator({'age': '1'});
      validator.validate({"age": 'min:10'});
      var errors = validator.getErrors();
      expect(errors['age'], 'The age must be greater than or equal 10');
    });

    test('min value', () {
      var validator = DoxValidator({'age': '10'});
      validator.validate({"age": 'min:10'});
      var errors = validator.getErrors();
      expect(errors['age'], null);
    });

    test('invalid max value', () {
      var validator = DoxValidator({'age': '11'});
      validator.validate({"age": 'max:10'});
      var errors = validator.getErrors();
      expect(errors['age'], 'The age must be less than or equal 10');
    });

    test('max value', () {
      var validator = DoxValidator({'age': '7'});
      validator.validate({"age": 'max:10'});
      var errors = validator.getErrors();
      expect(errors['age'], null);
    });

    test('invalid greater than', () {
      var validator = DoxValidator({'age': '6'});
      validator.validate({"age": 'greater_than:10'});
      var errors = validator.getErrors();
      expect(errors['age'], 'The age must be greater than 10');
    });

    test('greater than', () {
      var validator = DoxValidator({'age': '11'});
      validator.validate({"age": 'greater_than:10'});
      var errors = validator.getErrors();
      expect(errors['age'], null);
    });

    test('invalid less than', () {
      var validator = DoxValidator({'age': '11'});
      validator.validate({"age": 'less_than:10'});
      var errors = validator.getErrors();
      expect(errors['age'], 'The age must be less than 10');
    });

    test('less than', () {
      var validator = DoxValidator({'age': '7'});
      validator.validate({"age": 'less_than:10'});
      var errors = validator.getErrors();
      expect(errors['age'], null);
    });

    test('invalid start with', () {
      var validator = DoxValidator({'name': 'dox'});
      validator.validate({"name": 'start_with:dart'});
      var errors = validator.getErrors();
      expect(errors['name'], 'The name must start with dart');
    });

    test('start with', () {
      var validator = DoxValidator({'name': 'dox'});
      validator.validate({"name": 'start_with:do'});
      var errors = validator.getErrors();
      expect(errors['name'], null);
    });

    test('invalid end with', () {
      var validator = DoxValidator({'name': 'dox'});
      validator.validate({"name": 'end_with:dart'});
      var errors = validator.getErrors();
      expect(errors['name'], 'The name must end with dart');
    });

    test('end with', () {
      var validator = DoxValidator({'name': 'dox'});
      validator.validate({"name": 'end_with:x'});
      var errors = validator.getErrors();
      expect(errors['name'], null);
    });

    test('invalid confirmed', () {
      var validator = DoxValidator({
        'password': '12345678',
        'password_confirmation': '12345878',
      });
      validator.validate({"password": 'confirmed'});
      var errors = validator.getErrors();
      expect(errors['password'], 'The two password did not match');
    });

    test('invalid confirmed 2', () {
      var validator = DoxValidator({
        'password': '12345678',
        'password_confirmation': '12345678',
      });
      validator.validate({"password": 'confirmed'});
      var errors = validator.getErrors();
      expect(errors['password'], null);
    });

    test('invalid confirmed', () {
      var validator = DoxValidator({
        'password': '12345678',
        'password_confirm': '12345678',
      });
      validator.validate({"password": 'confirmed:password_confirm'});
      var errors = validator.getErrors();
      expect(errors['password'], null);
    });

    test('invalid required if', () {
      var validator = DoxValidator({
        'dob': '',
        'type': 'register',
      });
      validator.validate({"dob": 'required_if:type,register'});
      var errors = validator.getErrors();
      expect(errors['dob'], 'The dob is required');
    });

    test('required if', () {
      var validator = DoxValidator({
        'dob': '',
        'type': 'login',
      });
      validator.validate({"dob": 'required_if:type,register'});
      var errors = validator.getErrors();
      expect(errors['dob'], null);
    });

    test('required if 2', () {
      var validator = DoxValidator({
        'dob': '1994-22-11',
        'type': 'register',
      });
      validator.validate({"dob": 'required_if:type,register'});
      var errors = validator.getErrors();
      expect(errors['dob'], null);
    });

    test('invalid required if not', () {
      var validator = DoxValidator({
        'dob': '',
        'type': 'register',
      });
      validator.validate({"dob": 'required_if_not:type,login'});
      var errors = validator.getErrors();
      expect(errors['dob'], 'The dob is required');
    });

    test('required if not', () {
      var validator = DoxValidator({
        'dob': '',
        'type': 'login',
      });
      validator.validate({"dob": 'required_if_not:type,login'});
      var errors = validator.getErrors();
      expect(errors['dob'], null);
    });

    test('required if not 2', () {
      var validator = DoxValidator({
        'dob': '1994-22-11',
        'type': 'register',
      });
      validator.validate({"dob": 'required_if_not:type,login'});
      var errors = validator.getErrors();
      expect(errors['dob'], null);
    });

    test('with dots', () {
      Map<String, dynamic> data = {
        'products': [
          {
            "name": "iphone",
            "items": [
              {'title': 'charger'},
              {'title': 'case'},
            ]
          },
          {
            "name": "xbox",
            "items": [
              {'title': 'cable'},
              {'title': ''},
            ]
          }
        ],
      };
      var validator = DoxValidator(data);
      validator.validate({
        "products.*.items.*.title": 'required',
        "products.*.name": 'email',
      });
      var errors = validator.getErrors();
      expect(errors.length, 3);
    });
  });
}
