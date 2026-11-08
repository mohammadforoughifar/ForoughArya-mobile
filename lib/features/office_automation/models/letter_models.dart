// ============================================================
//  ماژول اتوماسیون اداری — مدل نامه‌ها
//  نامه داخلی / صادره / وارده + ارجاع + پیش‌نویس
// ============================================================

import 'office_common.dart';

/// سطر کارتابل (هر سه نوع نامه) — معادل InnerLetterListItemDto
class LetterListItem {
  const LetterListItem({
    required this.letterId,
    required this.title,
    this.letterNumber = '',
    this.erjaId,
    this.sender = '',
    this.senderUserId = 0,
    this.receiver = '',
    this.date,
    this.mahramanegi = 'عادی',
    this.foriat = 'عادی',
    this.erjaType,
    this.matnErja,
    this.deadline,
    this.isNeshan = false,
    this.hasAttachment = false,
    this.isRead = false,
    this.receiverCount = 0,
    this.typeTaeed = 0,
    this.hasAnswer = false,
    // ویژهٔ نامه وارده
    this.senderOrganization,
    // ویژهٔ نامه صادره
    this.receiverOrganization,
    this.outgoingStatus = 0,
    this.sadereNumber,
    this.isSignedByMe = false,
  });

  final int letterId;
  final String title;
  final String letterNumber;
  final int? erjaId;
  final String sender;
  final int senderUserId;
  final String receiver;
  final DateTime? date;
  final String mahramanegi;
  final String foriat;
  final String? erjaType;
  final String? matnErja;
  final DateTime? deadline;
  final bool isNeshan;
  final bool hasAttachment;
  final bool isRead;
  final int receiverCount;
  final int typeTaeed;
  final bool hasAnswer;
  final String? senderOrganization;
  final String? receiverOrganization;
  final int outgoingStatus;
  final String? sadereNumber;
  final bool isSignedByMe;

  bool get isConfidential => mahramanegi != 'عادی';
  bool get isUrgent => foriat != 'عادی';

  factory LetterListItem.fromJson(Map<String, dynamic> j) => LetterListItem(
    letterId: pickInt(j, ['letterId', 'LetterId', 'id', 'Id', 'sourceId']),
    title: pickStr(j, ['title', 'Title'], '(بدون عنوان)'),
    letterNumber: pickStr(j, ['letterNumber', 'LetterNumber', 'number']),
    erjaId: pickIntN(j, ['erjaId', 'ErjaId']),
    sender: pickStr(j, ['sender', 'Sender', 'senderName', 'SenderName', 'creator']),
    senderUserId: pickInt(j, ['senderUserId', 'SenderUserId', 'creatorUserId']),
    receiver: pickStr(j, ['reciver', 'Reciver', 'reciverName', 'ReciverName']),
    date: pickDate(j, ['date', 'Date', 'dateSabt', 'DateSabt']),
    mahramanegi: pickStr(j, ['mahramanegi', 'Mahramanegi'], 'عادی'),
    foriat: pickStr(j, ['foriat', 'Foriat'], 'عادی'),
    erjaType: pickStrN(j, ['erjaType', 'ErjaType', 'type']),
    matnErja: pickStrN(j, ['matnErja', 'MatnErja']),
    deadline: pickDate(j, ['mohlatPasokh', 'MohlatPasokh']),
    isNeshan: pickBool(j, ['isNeshan', 'IsNeshan']),
    hasAttachment: pickBool(j, ['hasAttachment', 'HasAttachment']),
    isRead: pickBool(j, ['isRead', 'IsRead']),
    receiverCount: pickInt(j, ['reciverCount', 'ReciverCount']),
    typeTaeed: pickInt(j, ['typeTaeed', 'TypeTaeed']),
    hasAnswer: pickBool(j, ['hasAnswer', 'HasAnswer']),
    senderOrganization:
        pickStrN(j, ['senderOrganization', 'SenderOrganization', 'ferestande']),
    receiverOrganization: pickStrN(j, ['receiverOrganization', 'ReceiverOrganization']),
    outgoingStatus: pickInt(j, ['status', 'Status']),
    sadereNumber: pickStrN(j, ['sadereNumber', 'SadereNumber']),
    isSignedByMe: pickBool(j, ['isSignedByMe', 'IsSignedByMe', 'mySigned']),
  );
}

/// جزئیات کامل نامه داخلی — معادل InnerLetterDetailDto
class InnerLetterDetail {
  const InnerLetterDetail({
    required this.letterId,
    required this.title,
    this.letterNumber = '',
    this.number = 0,
    this.text,
    this.mahramanegi = 'عادی',
    this.foriat = 'عادی',
    this.dateSabt,
    this.senderUserId = 0,
    this.senderName = '',
    this.girande = const [],
    this.erja = const [],
    this.hamesh = const [],
    this.relatedLetters = const [],
    this.myErja,
    this.isMine = false,
    this.canEdit = false,
  });

  final int letterId;
  final String title;
  final String letterNumber;
  final int number;
  final String? text;
  final String mahramanegi;
  final String foriat;
  final DateTime? dateSabt;
  final int senderUserId;
  final String senderName;
  final List<LetterRecipient> girande;
  final List<LetterRecipient> erja;
  final List<LetterRecipient> hamesh;
  final List<RelatedLetter> relatedLetters;
  final ErjaItem? myErja;
  final bool isMine;
  final bool canEdit;

  factory InnerLetterDetail.fromJson(Map<String, dynamic> j) => InnerLetterDetail(
    letterId: pickInt(j, ['letterId', 'LetterId', 'id']),
    title: pickStr(j, ['title', 'Title'], '(بدون عنوان)'),
    letterNumber: pickStr(j, ['letterNumber', 'LetterNumber']),
    number: pickInt(j, ['number', 'Number']),
    text: pickStrN(j, ['text', 'Text']),
    mahramanegi: pickStr(j, ['mahramanegi', 'Mahramanegi'], 'عادی'),
    foriat: pickStr(j, ['foriat', 'Foriat'], 'عادی'),
    dateSabt: pickDate(j, ['dateSabt', 'DateSabt', 'date']),
    senderUserId: pickInt(j, ['senderUserId', 'SenderUserId', 'creatorUserId']),
    senderName: pickStr(j, ['senderName', 'SenderName', 'creator']),
    girande: pickList(j, ['reciversGirande', 'ReciversGirande'], LetterRecipient.fromJson),
    erja: pickList(j, ['reciversErja', 'ReciversErja'], LetterRecipient.fromJson),
    hamesh: pickList(j, ['reciversHamesh', 'ReciversHamesh'], LetterRecipient.fromJson),
    relatedLetters: pickList(j, ['relatedLetters', 'RelatedLetters'], RelatedLetter.fromJson),
    myErja: pick(j, ['myErja', 'MyErja']) is Map
        ? ErjaItem.fromJson(asMap(pick(j, ['myErja', 'MyErja'])))
        : null,
    isMine: pickBool(j, ['isMine', 'IsMine']),
    canEdit: pickBool(j, ['canEdit', 'CanEdit']),
  );
}

/// جزئیات نامه صادره — افزوده‌های گیرنده بیرونی، امضا و دبیرخانه
class OutgoingLetterDetail {
  const OutgoingLetterDetail({
    required this.letterId,
    required this.title,
    this.letterNumber = '',
    this.text,
    this.mahramanegi = 'عادی',
    this.foriat = 'عادی',
    this.dateSabt,
    this.senderUserId = 0,
    this.senderName = '',
    this.receiverOrganization = '',
    this.receiverName,
    this.receiverTitle,
    this.receiverAddress,
    this.copyTo,
    this.copyTos = const [],
    this.externalRefNumber,
    this.companyId,
    this.sadereNumber,
    this.dateSadere,
    this.status = 0,
    this.isNeshan = false,
    this.girande = const [],
    this.erja = const [],
    this.hamesh = const [],
    this.relatedLetters = const [],
    this.signers = const [],
    this.myErja,
    this.isMine = false,
    this.canEdit = false,
    // دبیرخانه
    this.dabirkhaneSabt = false,
    this.dateDabirkhane,
    this.destRegNumber,
    this.sendMethod,
    this.dabirkhaneNote,
    this.delivererName,
    this.trackingCode,
    this.destFax,
    this.destEmail,
    this.isArchived = false,
    this.archivedAt,
  });

  final int letterId;
  final String title;
  final String letterNumber;
  final String? text;
  final String mahramanegi;
  final String foriat;
  final DateTime? dateSabt;
  final int senderUserId;
  final String senderName;

  final String receiverOrganization;
  final String? receiverName;
  final String? receiverTitle;
  final String? receiverAddress;
  final String? copyTo;
  final List<CopyToPerson> copyTos;
  final String? externalRefNumber;
  final int? companyId;

  final String? sadereNumber;
  final DateTime? dateSadere;
  final int status;
  final bool isNeshan;

  final List<LetterRecipient> girande;
  final List<LetterRecipient> erja;
  final List<LetterRecipient> hamesh;
  final List<RelatedLetter> relatedLetters;
  final List<OutgoingSigner> signers;
  final ErjaItem? myErja;
  final bool isMine;
  final bool canEdit;

  final bool dabirkhaneSabt;
  final DateTime? dateDabirkhane;
  final String? destRegNumber;
  final String? sendMethod;
  final String? dabirkhaneNote;
  final String? delivererName;
  final String? trackingCode;
  final String? destFax;
  final String? destEmail;
  final bool isArchived;
  final DateTime? archivedAt;

  bool get isIssued => status == 3 || (sadereNumber?.isNotEmpty ?? false);
  String get statusLabel =>
      status >= 0 && status < OfficeConst.outgoingStatus.length
      ? OfficeConst.outgoingStatus[status]
      : 'نامشخص';

  /// آیا نوبت امضای کاربر جاری است؟ (ترتیب امضا رعایت می‌شود)
  bool get isMyTurnToSign {
    final pending = signers.where((s) => !s.isSigned).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    if (pending.isEmpty) return false;
    return pending.first.isMe;
  }

  factory OutgoingLetterDetail.fromJson(Map<String, dynamic> j) =>
      OutgoingLetterDetail(
        letterId: pickInt(j, ['letterId', 'LetterId', 'id']),
        title: pickStr(j, ['title', 'Title'], '(بدون عنوان)'),
        letterNumber: pickStr(j, ['letterNumber', 'LetterNumber']),
        text: pickStrN(j, ['text', 'Text']),
        mahramanegi: pickStr(j, ['mahramanegi', 'Mahramanegi'], 'عادی'),
        foriat: pickStr(j, ['foriat', 'Foriat'], 'عادی'),
        dateSabt: pickDate(j, ['dateSabt', 'DateSabt']),
        senderUserId: pickInt(j, ['senderUserId', 'SenderUserId', 'creatorUserId']),
        senderName: pickStr(j, ['senderName', 'SenderName', 'creator']),
        receiverOrganization:
            pickStr(j, ['receiverOrganization', 'ReceiverOrganization']),
        receiverName: pickStrN(j, ['receiverName', 'ReceiverName']),
        receiverTitle: pickStrN(j, ['receiverTitle', 'ReceiverTitle']),
        receiverAddress: pickStrN(j, ['receiverAddress', 'ReceiverAddress']),
        copyTo: pickStrN(j, ['copyTo', 'CopyTo']),
        copyTos: pickList(j, ['copyTos', 'CopyTos'], CopyToPerson.fromJson),
        externalRefNumber: pickStrN(j, ['externalRefNumber', 'ExternalRefNumber']),
        companyId: pickIntN(j, ['companyId', 'CompanyId']),
        sadereNumber: pickStrN(j, ['sadereNumber', 'SadereNumber']),
        dateSadere: pickDate(j, ['dateSadere', 'DateSadere']),
        status: pickInt(j, ['status', 'Status']),
        isNeshan: pickBool(j, ['isNeshan', 'IsNeshan']),
        girande: pickList(j, ['reciversGirande', 'ReciversGirande'], LetterRecipient.fromJson),
        erja: pickList(j, ['reciversErja', 'ReciversErja'], LetterRecipient.fromJson),
        hamesh: pickList(j, ['reciversHamesh', 'ReciversHamesh'], LetterRecipient.fromJson),
        relatedLetters: pickList(j, ['relatedLetters', 'RelatedLetters'], RelatedLetter.fromJson),
        signers: pickList(j, ['signers', 'Signers'], OutgoingSigner.fromJson),
        myErja: pick(j, ['myErja', 'MyErja']) is Map
            ? ErjaItem.fromJson(asMap(pick(j, ['myErja', 'MyErja'])))
            : null,
        isMine: pickBool(j, ['isMine', 'IsMine']),
        canEdit: pickBool(j, ['canEdit', 'CanEdit']),
        dabirkhaneSabt: pickBool(j, ['dabirkhaneSabt', 'DabirkhaneSabt']),
        dateDabirkhane: pickDate(j, ['dateDabirkhane', 'DateDabirkhane']),
        destRegNumber: pickStrN(j, ['destRegNumber', 'DestRegNumber']),
        sendMethod: pickStrN(j, ['sendMethod', 'SendMethod']),
        dabirkhaneNote: pickStrN(j, ['dabirkhaneNote', 'DabirkhaneNote']),
        delivererName: pickStrN(j, ['delivererName', 'DelivererName']),
        trackingCode: pickStrN(j, ['trackingCode', 'TrackingCode']),
        destFax: pickStrN(j, ['destFax', 'DestFax']),
        destEmail: pickStrN(j, ['destEmail', 'DestEmail']),
        isArchived: pickBool(j, ['isArchived', 'IsArchived']),
        archivedAt: pickDate(j, ['archivedAt', 'ArchivedAt']),
      );
}

/// رونوشت‌گیرندهٔ نامه صادره — جدول مستقل OutgoingLetterCopyTo
class CopyToPerson {
  const CopyToPerson({
    required this.id,
    this.name = '',
    this.organization = '',
    this.title = '',
  });

  final int id;
  final String name;
  final String organization;
  final String title;

  String get label => [
    organization,
    name,
    title,
  ].where((e) => e.trim().isNotEmpty).join(' — ');

  factory CopyToPerson.fromJson(Map<String, dynamic> j) => CopyToPerson(
    id: pickInt(j, ['id', 'Id']),
    name: pickStr(j, ['name', 'Name', 'personName', 'PersonName']),
    organization: pickStr(j, ['organization', 'Organization']),
    title: pickStr(j, ['title', 'Title', 'personTitle']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'organization': organization,
    'title': title,
  };
}

/// امضاکنندهٔ نامه صادره — معادل OutgoingSignerDto
class OutgoingSigner {
  const OutgoingSigner({
    required this.id,
    required this.userId,
    required this.userName,
    this.order = 1,
    this.isSigned = false,
    this.dateSigned,
    this.signNote,
    this.sematTitle,
    this.isMe = false,
  });

  final int id;
  final int userId;
  final String userName;
  final int order;
  final bool isSigned;
  final DateTime? dateSigned;
  final String? signNote;
  final String? sematTitle;
  final bool isMe;

  factory OutgoingSigner.fromJson(Map<String, dynamic> j) => OutgoingSigner(
    id: pickInt(j, ['id', 'Id']),
    userId: pickInt(j, ['userId', 'UserId']),
    userName: pickStr(j, ['userName', 'UserName', 'name']),
    order: pickInt(j, ['order', 'Order'], 1),
    isSigned: pickBool(j, ['isSigned', 'IsSigned']),
    dateSigned: pickDate(j, ['dateSigned', 'DateSigned']),
    signNote: pickStrN(j, ['signNote', 'SignNote']),
    sematTitle: pickStrN(j, ['sematTitle', 'SematTitle']),
    isMe: pickBool(j, ['isMe', 'IsMe', 'myTurn']),
  );
}

/// یک ردیف ارجاع — معادل ErjaDto
class ErjaItem {
  const ErjaItem({
    required this.erjaId,
    required this.sourceId,
    required this.senderUserId,
    required this.receiverUserId,
    this.senderName = '',
    this.receiverName = '',
    this.date,
    this.type = 'گیرنده',
    this.typeTaeed = 0,
    this.answer = '',
    this.isRead = false,
    this.deadline,
    this.matnErja = '',
    this.amalgarId = 1,
    this.amalgarTitle,
    this.isNeshan = false,
    this.showForAll = false,
    this.dateRead,
    this.dateEmza,
    this.dateAnswer,
    this.parentErjaId,
  });

  final int erjaId;
  final int sourceId;
  final int senderUserId;
  final int receiverUserId;
  final String senderName;
  final String receiverName;
  final DateTime? date;
  final String type;
  final int typeTaeed;
  final String answer;
  final bool isRead;
  final DateTime? deadline;
  final String matnErja;
  final int amalgarId;
  final String? amalgarTitle;
  final bool isNeshan;
  final bool showForAll;
  final DateTime? dateRead;
  final DateTime? dateEmza;
  final DateTime? dateAnswer;
  final int? parentErjaId;

  String get taeedLabel => typeTaeed >= 0 && typeTaeed < OfficeConst.taeedLabels.length
      ? OfficeConst.taeedLabels[typeTaeed]
      : '';

  factory ErjaItem.fromJson(Map<String, dynamic> j) => ErjaItem(
    erjaId: pickInt(j, ['erjaId', 'ErjaId']),
    sourceId: pickInt(j, ['sourceId', 'SourceId']),
    senderUserId: pickInt(j, ['senderUserId', 'SenderUserId']),
    receiverUserId: pickInt(j, ['reciverUserId', 'ReciverUserId', 'receiverUserId']),
    senderName: pickStr(j, ['senderName', 'SenderName', 'sender']),
    receiverName: pickStr(j, ['reciverName', 'ReciverName', 'receiverName']),
    date: pickDate(j, ['date', 'Date', 'dateErja']),
    type: pickStr(j, ['type', 'Type'], 'گیرنده'),
    typeTaeed: pickInt(j, ['typeTaeed', 'TypeTaeed']),
    answer: pickStr(j, ['answer', 'Answer', 'matnPasokh']),
    isRead: pickBool(j, ['isRead', 'IsRead']),
    deadline: pickDate(j, ['mohlatPasokh', 'MohlatPasokh']),
    matnErja: pickStr(j, ['matnErja', 'MatnErja']),
    amalgarId: pickInt(j, ['amalgarId', 'AmalgarId'], 1),
    amalgarTitle: pickStrN(j, ['amalgarTitle', 'AmalgarTitle']),
    isNeshan: pickBool(j, ['isNeshan', 'IsNeshan']),
    showForAll: pickBool(j, ['showForAll', 'ShowForAll']),
    dateRead: pickDate(j, ['dateRead', 'DateRead']),
    dateEmza: pickDate(j, ['dateEmza', 'DateEmza']),
    dateAnswer: pickDate(j, ['dateAnswer', 'DateAnswer', 'datePasokh']),
    parentErjaId: pickIntN(j, ['parentErjaId', 'ParentErjaId']),
  );
}

/// پیش‌نویس نامه — معادل PishnevisLetter
class DraftLetter {
  const DraftLetter({
    required this.id,
    required this.title,
    this.text = '',
    this.userId = 0,
    this.userName = '',
    this.isNeshan = false,
    this.receiverOrganization,
    this.receiverName,
    this.createdAt,
  });

  final int id;
  final String title;
  final String text;
  final int userId;
  final String userName;
  final bool isNeshan;
  final String? receiverOrganization;
  final String? receiverName;
  final DateTime? createdAt;

  factory DraftLetter.fromJson(Map<String, dynamic> j) => DraftLetter(
    id: pickInt(j, ['pishnevisId', 'PishnevisId', 'id', 'Id']),
    title: pickStr(j, ['title', 'Title'], '(بدون عنوان)'),
    text: pickStr(j, ['text', 'Text']),
    userId: pickInt(j, ['userId', 'UserId']),
    userName: pickStr(j, ['userName', 'UserName', 'user']),
    isNeshan: pickBool(j, ['isNeshan', 'IsNeshan']),
    receiverOrganization: pickStrN(j, ['receiverOrganization', 'ReceiverOrganization']),
    receiverName: pickStrN(j, ['receiverName', 'ReceiverName']),
    createdAt: pickDate(j, ['createdAt', 'CreatedAt', 'date']),
  );
}
