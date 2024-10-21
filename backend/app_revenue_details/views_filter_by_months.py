# app_revenue_details/views_filter_by_months.py

import json
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import JSONParser
from django.db.models import Sum
from datetime import datetime
from decimal import Decimal
from app_income_parkir.models import IncomeParkir
from app_income_member.models import IncomeMember
from app_income_manual.models import IncomeManual
from app_users.utils import get_session_data_from_body, fetch_user_locations, is_admin_user

@method_decorator(csrf_exempt, name='dispatch')
class RevenueDetailsByMonthsView(APIView):
    parser_classes = [JSONParser]

    def get(self, request, *args, **kwargs):
        try:
            # Step 1: Get session data from body or fallback to query params/headers
            session_data_result = get_session_data_from_body(request)
            if isinstance(session_data_result, dict) and 'error' in session_data_result:
                session_data_str = request.GET.get('session_data') or request.headers.get('X-Session-Data')
                if session_data_str:
                    try:
                        session_data = json.loads(session_data_str)
                    except json.JSONDecodeError:
                        return Response({"status": "error", "message": "Invalid session data format"}, status=400)
                else:
                    return Response({"status": "error", "message": session_data_result['error']}, status=400)
            else:
                session_data = session_data_result

            # Step 2: Check if user is admin
            is_admin = is_admin_user(session_data)
            if isinstance(is_admin, dict) and 'error' in is_admin:
                return Response({"status": "error", "message": is_admin['error']}, status=400)

            # Step 3: Fetch valid user locations based on session data
            locations = fetch_user_locations(session_data)
            if isinstance(locations, dict) and 'error' in locations:
                return Response({"status": "error", "message": locations['error']}, status=400)

            # Check if this is a request for locations or for revenue details
            if 'locations' in request.path:
                return self.get_locations(request)
            else:
                return self.view_by_locations(request, locations)
          
        except Exception as e:
            return Response({"status": "error", "message": f"Terjadi kesalahan: {str(e)}"}, status=500)

    def get_locations(self, request):
        try:
            # Step 1: Get session data
            session_data_result = get_session_data_from_body(request)
            if isinstance(session_data_result, dict) and 'error' in session_data_result:
                session_data_str = request.GET.get('session_data') or request.headers.get('X-Session-Data')
                if session_data_str:
                    try:
                        session_data = json.loads(session_data_str)
                    except json.JSONDecodeError:
                        return Response({"status": "error", "message": "Invalid session data format"}, status=400)
                else:
                    return Response({"status": "error", "message": session_data_result['error']}, status=400)
            else:
                session_data = session_data_result

            # Step 2: Check if user is admin
            is_admin = is_admin_user(session_data)
            if isinstance(is_admin, dict) and 'error' in is_admin:
                return Response({"status": "error", "message": is_admin['error']}, status=400)

            # Step 3: Fetch user locations
            locations = fetch_user_locations(session_data)
            if isinstance(locations, dict) and 'error' in locations:
                return Response({"status": "error", "message": locations['error']}, status=400)

            # Step 4: Get unique locations from IncomeParkir model
            unique_locations = IncomeParkir.objects.filter(id_lokasi__in=locations) \
                .values_list('id_lokasi__site', flat=True) \
                .distinct() \
                .order_by('id_lokasi')

            return Response({"status": "success", "locations": list(unique_locations)}, status=200)

        except Exception as e:
            return Response({"status": "error", "message": f"Terjadi kesalahan: {str(e)}"}, status=500)

    def view_by_locations(self, request, locations):
        try:
            year = request.GET.get('year')

            if not year:
                return Response({"status": "error", "message": "Year filter is required."}, status=400)

            try:
                year = int(year)
            except ValueError:
                return Response({"status": "error", "message": "Invalid year format."}, status=400)

            start_date = datetime(year, 1, 1)
            end_date = datetime(year, 12, 31)

            # Fetch data dari 3 models
            parkir_data = IncomeParkir.objects.filter(id_lokasi__in=locations, tanggal__range=[start_date, end_date]) \
                .values('id_lokasi__site', 'tanggal__month') \
                .annotate(cash=Sum('cash'), prepaid=Sum('prepaid'), casual=Sum('casual'), pass_field=Sum('pass_field')) \
                .order_by('id_lokasi__site', 'tanggal__month')

            member_data = IncomeMember.objects.filter(id_lokasi__in=locations, tanggal__range=[start_date, end_date]) \
                .values('id_lokasi__site', 'tanggal__month') \
                .annotate(member=Sum('member'))

            manual_data = IncomeManual.objects.filter(id_lokasi__in=locations, tanggal__range=[start_date, end_date]) \
                .values('id_lokasi__site', 'tanggal__month') \
                .annotate(manual=Sum('manual'), masalah=Sum('masalah')) \
                .order_by('id_lokasi__site', 'tanggal__month')

            result = {}

            for parkir in parkir_data:
                lokasi = parkir['id_lokasi__site']
                bulan = parkir['tanggal__month']  

                cash = Decimal(parkir['cash'] or 0)
                prepaid = Decimal(parkir['prepaid'] or 0)
                casual = Decimal(parkir['casual'] or 0)
                pass_field = Decimal(parkir['pass_field'] or 0)
                
                member = Decimal(next((m['member'] for m in member_data if m['tanggal__month'] == bulan and m['id_lokasi__site'] == lokasi), 0))
                
                manual = Decimal(next((man['manual'] for man in manual_data if man['tanggal__month'] == bulan and man['id_lokasi__site'] == lokasi), 0) or 0)
                masalah = Decimal(next((man['masalah'] for man in manual_data if man['tanggal__month'] == bulan and man['id_lokasi__site'] == lokasi), 0) or 0)

                total_qty = casual + pass_field
                total_pendapatan = cash + prepaid + manual + member - masalah

                if lokasi not in result:
                    result[lokasi] = []

                result[lokasi].append({
                    'bulan': bulan,  
                    'tarif_tunai': cash,
                    'tarif_non_tunai': prepaid,
                    'member': member,
                    'manual': manual,
                    'tiket_masalah': masalah,
                    'total_pendapatan': total_pendapatan,
                    'qty_casual': casual,
                    'qty_pass': pass_field,
                    'total_qty': total_qty
                })

            # Perhitungan total, min, max, avg untuk setiap lokasi
            for lokasi, data_list in result.items():
                totals = {
                    'tarif_tunai': sum(d['tarif_tunai'] for d in data_list),
                    'tarif_non_tunai': sum(d['tarif_non_tunai'] for d in data_list),
                    'member': sum(d['member'] for d in data_list),
                    'manual': sum(d['manual'] for d in data_list),
                    'tiket_masalah': sum(d['tiket_masalah'] for d in data_list),
                    'total_pendapatan': sum(d['total_pendapatan'] for d in data_list),
                    'qty_casual': sum(d['qty_casual'] for d in data_list),
                    'qty_pass': sum(d['qty_pass'] for d in data_list),
                    'total_qty': sum(d['total_qty'] for d in data_list)
                }

                minimal = {key: min(d[key] for d in data_list) for key in totals.keys()}
                maksimal = {key: max(d[key] for d in data_list) for key in totals.keys()}
                rerata = {key: value / len(data_list) for key, value in totals.items()}

                result[lokasi].append({
                    'total': totals,
                    'minimal': minimal,
                    'maksimal': maksimal,
                    'rata-rata': rerata
                })

            return Response(result, status=200)

        except Exception as e:
            return Response({"status": "error", "message": f"Error processing data: {str(e)}"}, status=500)