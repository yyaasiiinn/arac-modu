import 'package:car_mode/core/contacts_repo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = ContactsRepo.I;
  final people = [
    const SimpleContact('Annem', ['05551112233'], null),
    const SimpleContact('Ahmet Yılmaz', ['05321234567'], null),
    const SimpleContact('Ayşe', ['05000000000'], null),
  ];
  test('isim eşleşmesi', () {
    expect(repo.findInSpeech('annemi ara', extra: people)?.name, 'Annem');
    expect(repo.findInSpeech("Ahmet'i ara", extra: people)?.name, 'Ahmet Yılmaz');
    expect(repo.findInSpeech('Ayşeye mesaj gönder geliyorum', extra: people)?.name, 'Ayşe');
    expect(repo.findInSpeech('eve git', extra: people), isNull);
  });
  test('norm', () {
    expect(ContactsRepo.norm('Şükrü İĞNE'), 'sukru igne');
  });
}
