# Veli izni dizgeleri, 12 dil örneklemi (2026-11-16)

Kapsam: `ParentalConsentCopy` 5 dizgenin tamamı (5 x 14 dil). Kaynak EN/TR değişmedi; id = sha256(en+"\0"+tr)[:16]. Yer tutucu yok (pariteyi `ui_copy_catalog_test` doğrular). Hitap: de du, fr tu, es-419 tú, pt-BR você, id kamu, it tu, ja です/ます, ko 하세요/합니다, pl ty, hi आप, zh 你. Metinlerde vaat, tedavi, garanti, "yakında" ve "yanlış" dili yok; `validate_surface_honesty.py` rc=0.

Not: ilk taslakta fr/hi/id/zh-Hans'taki "şimdilik/henüz" kalıpları (pour le moment, अभी, belum, 暂时) bekçiye takıldı; bekçi gevşetilmeden metin nötrlendi ("şu anda" ifadesi bu dillerde düşürüldü). Yerel konuşur gözden geçirmesi bekliyor.

## checkApproval (`b6464c47036b1033`)

- en: Check approval
- tr: Onayı kontrol et
- ar: تحقّق من الموافقة
- de: Zustimmung prüfen
- es-419: Revisar la aprobación
- fr: Vérifier l’approbation
- hi: मंज़ूरी जाँचें
- id: Periksa persetujuan
- it: Controlla l'approvazione
- ja: 承認を確認する
- ko: 승인 확인하기
- pl: Sprawdź zgodę
- pt-BR: Verificar aprovação
- zh-Hans: 查看批准状态

## dailyLimit (`55bbed4c515fa63a`)

- en: Too many requests were sent today. Please try again tomorrow.
- tr: Bugün çok fazla istek gönderildi. Lütfen yarın tekrar dene.
- ar: أُرسل اليوم عدد كبير من الطلبات. يُرجى المحاولة مرة أخرى غدًا.
- de: Heute wurden zu viele Anfragen gesendet. Bitte versuche es morgen noch einmal.
- es-419: Hoy se enviaron demasiadas solicitudes. Inténtalo de nuevo mañana.
- fr: Trop de demandes ont été envoyées aujourd’hui. Réessaie demain.
- hi: आज बहुत ज़्यादा अनुरोध भेजे गए। कृपया कल फिर कोशिश करें।
- id: Terlalu banyak permintaan dikirim hari ini. Coba lagi besok.
- it: Oggi sono state inviate troppe richieste. Riprova domani.
- ja: 今日は送信されたリクエストが多すぎます。明日もう一度お試しください。
- ko: 오늘은 요청이 너무 많이 전송되었습니다. 내일 다시 시도하세요.
- pl: Dziś wysłano zbyt wiele próśb. Spróbuj ponownie jutro.
- pt-BR: Muitas solicitações foram enviadas hoje. Tente novamente amanhã.
- zh-Hans: 今天发送的请求过多。请明天再试。

## unavailable (`8df76a80597f7226`)

- en: We could not confirm the status just now. If you sent a request, it may have gone through. Please check again later.
- tr: Şu anda durumu doğrulayamadık. Bir istek gönderdiysen iletilmiş olabilir. Lütfen daha sonra tekrar kontrol et.
- ar: تعذّر علينا تأكيد الحالة الآن. إذا كنت قد أرسلت طلبًا، فربما تم إرساله. يُرجى التحقق مرة أخرى لاحقًا.
- de: Wir konnten den Status gerade nicht bestätigen. Wenn du eine Anfrage gesendet hast, wurde sie möglicherweise übermittelt. Bitte prüfe später noch einmal.
- es-419: No pudimos confirmar el estado en este momento. Si enviaste una solicitud, es posible que se haya enviado. Vuelve a revisar más tarde.
- fr: Nous n’avons pas pu confirmer l’état. Si tu as envoyé une demande, elle a peut-être été transmise. Vérifie de nouveau plus tard.
- hi: हम स्थिति की पुष्टि नहीं कर सके। अगर आपने कोई अनुरोध भेजा था, तो वह पहुँच गया हो सकता है। कृपया बाद में फिर जाँचें।
- id: Kami tidak dapat memastikan statusnya. Jika kamu sudah mengirim permintaan, permintaan itu mungkin sudah terkirim. Coba periksa lagi nanti.
- it: Al momento non siamo riusciti a confermare lo stato. Se hai inviato una richiesta, potrebbe essere stata inoltrata. Ricontrolla più tardi.
- ja: いま状況を確認できませんでした。リクエストを送信済みの場合は、届いている可能性があります。後でもう一度確認してください。
- ko: 지금은 상태를 확인할 수 없었습니다. 요청을 보냈다면 전달되었을 수 있습니다. 나중에 다시 확인하세요.
- pl: Nie udało nam się teraz potwierdzić statusu. Jeśli prośba została wysłana, mogła zostać przekazana. Sprawdź ponownie później.
- pt-BR: Não conseguimos confirmar o status agora. Se você enviou uma solicitação, ela pode ter sido enviada. Verifique novamente mais tarde.
- zh-Hans: 我们无法确认状态。如果你已发送请求，它可能已经送达。请稍后再查看。

## approved (`df0cf1db48b815d1`)

- en: Your parent or guardian approved. You can create your account now.
- tr: Velin onayladı. Artık hesabını oluşturabilirsin.
- ar: وافق والدك أو ولي أمرك. يمكنك إنشاء حسابك الآن.
- de: Deine Eltern oder deine Erziehungsberechtigten haben zugestimmt. Du kannst jetzt dein Konto erstellen.
- es-419: Tu madre, padre o tutor dio su aprobación. Ya puedes crear tu cuenta.
- fr: Ton parent ou ton responsable légal a donné son accord. Tu peux maintenant créer ton compte.
- hi: आपके माता-पिता या अभिभावक ने मंज़ूरी दे दी है। अब आप अपना खाता बना सकते हैं।
- id: Orang tua atau walimu sudah menyetujui. Sekarang kamu bisa membuat akunmu.
- it: Il tuo genitore o tutore ha approvato. Ora puoi creare il tuo account.
- ja: 保護者の方が承認しました。アカウントを作成できます。
- ko: 보호자가 승인했습니다. 이제 계정을 만들 수 있습니다.
- pl: Twój rodzic lub opiekun wyraził zgodę. Możesz teraz założyć konto.
- pt-BR: Seu responsável aprovou. Você já pode criar sua conta.
- zh-Hans: 你的家长或监护人已批准。你现在可以创建账号了。

## denied (`43f870c1b952fe9d`)

- en: A decision was recorded for this request. An account can’t be created on this device.
- tr: Bu istek için bir karar kaydedildi. Bu cihazda hesap oluşturulamıyor.
- ar: تم تسجيل قرار بشأن هذا الطلب. لا يمكن إنشاء حساب على هذا الجهاز.
- de: Für diese Anfrage wurde eine Entscheidung gespeichert. Auf diesem Gerät kann kein Konto erstellt werden.
- es-419: Se registró una decisión para esta solicitud. No se puede crear una cuenta en este dispositivo.
- fr: Une décision a été enregistrée pour cette demande. Il n’est pas possible de créer un compte sur cet appareil.
- hi: इस अनुरोध के लिए एक निर्णय दर्ज किया गया। इस डिवाइस पर खाता नहीं बनाया जा सकता।
- id: Sebuah keputusan telah dicatat untuk permintaan ini. Akun tidak dapat dibuat di perangkat ini.
- it: È stata registrata una decisione per questa richiesta. Non è possibile creare un account su questo dispositivo.
- ja: このリクエストについて、決定が記録されました。この端末ではアカウントを作成できません。
- ko: 이 요청에 대한 결정이 기록되었습니다. 이 기기에서는 계정을 만들 수 없습니다.
- pl: Dla tej prośby zapisano decyzję. Na tym urządzeniu nie można utworzyć konta.
- pt-BR: Uma decisão foi registrada para esta solicitação. Não é possível criar uma conta neste dispositivo.
- zh-Hans: 这个请求已记录了一项决定。此设备上无法创建账号。
