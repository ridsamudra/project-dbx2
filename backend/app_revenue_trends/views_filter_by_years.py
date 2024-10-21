# app_revenue_trends/views_filter_by_years.py

import json
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import JSONParser
from decimal import Decimal
from django.db.models import Sum
from django.db.models.functions import TruncYear
from dateutil.relativedelta import relativedelta
from app_income_parkir.models import IncomeParkir
from app_income_member.models import IncomeMember
from app_income_manual.models import IncomeManual
# from app_locations.models import Locations
from app_users.utils import get_session_data_from_body, fetch_user_locations, is_admin_user

@method_decorator(csrf_exempt, name='dispatch')
class RevenueByYearsView(APIView):
    parser_classes = [JSONParser]

    def get(self, request, *args, **kwargs):
        try:
            # Step 1: Get session data from request body or fallback
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

            # Step 4: Determine if we need view_all or view_by_locations            
            if request.path.endswith('bylocations'):
                return self.view_by_locations(locations)
            else:
                return self.view_all(locations)


        except Exception as e:
            return Response({"status": "error", "message": f"Terjadi kesalahan: {str(e)}"}, status=500)

    def view_all(self, locations):
        try:
            # Get the latest year in the database
            latest_date = IncomeParkir.objects.order_by('-tanggal').first().tanggal
            start_date = (latest_date - relativedelta(years=5)).replace(month=1, day=1)

            # Query for income data
            parkir_data = IncomeParkir.objects.filter(id_lokasi__in=locations, tanggal__range=[start_date, latest_date]) \
                .annotate(year=TruncYear('tanggal')) \
                .values('year') \
                .annotate(cash=Sum('cash'), prepaid=Sum('prepaid')) \
                .order_by('year')

            member_data = IncomeMember.objects.filter(id_lokasi__in=locations,tanggal__range=[start_date, latest_date]) \
                .annotate(year=TruncYear('tanggal')) \
                .values('year') \
                .annotate(member=Sum('member'))

            manual_data = IncomeManual.objects.filter(id_lokasi__in=locations,tanggal__range=[start_date, latest_date]) \
                .annotate(year=TruncYear('tanggal')) \
                .values('year') \
                .annotate(manual=Sum('manual'), masalah=Sum('masalah')) \
                .order_by('year')

            # Prepare the response data
            result = []
            for date in parkir_data:
                date_value = date['year']
                cash = Decimal(date['cash'] or 0)
                prepaid = Decimal(date['prepaid'] or 0)
                member = Decimal(next((item['member'] for item in member_data if item['year'] == date_value), 0))
                manual = Decimal(next((item['manual'] for item in manual_data if item['year'] == date_value), 0))
                masalah = Decimal(next((item['masalah'] for item in manual_data if item['year'] == date_value), 0))

                total = cash + prepaid + manual + member - masalah

                result.append({
                    'tanggal': date_value.year,
                    'cash': cash,
                    'prepaid': prepaid,
                    'member': member,
                    'manual': manual,
                    'masalah': masalah,
                    'total': total
                })

            return Response(result[:6], status=200)  # Limit to last 6 years

        except Exception as e:
            return Response({"status": "error", "message": f"Error in view_all: {str(e)}"}, status=500)

    def view_by_locations(self, locations):
        try:
            # Get the latest year in the database
            latest_date = IncomeParkir.objects.order_by('-tanggal').first().tanggal
            start_date = (latest_date - relativedelta(years=5)).replace(month=1, day=1)

            # Query for income data by location
            parkir_data = IncomeParkir.objects.filter(id_lokasi__in=locations, tanggal__range=[start_date, latest_date]) \
                .annotate(year=TruncYear('tanggal')) \
                .values('year', 'id_lokasi__site') \
                .annotate(cash=Sum('cash'), prepaid=Sum('prepaid')) \
                .order_by('year')

            member_data = IncomeMember.objects.filter(id_lokasi__in=locations, tanggal__range=[start_date, latest_date]) \
                .annotate(year=TruncYear('tanggal')) \
                .values('year', 'id_lokasi__site') \
                .annotate(member=Sum('member'))

            manual_data = IncomeManual.objects.filter(id_lokasi__in=locations, tanggal__range=[start_date, latest_date]) \
                .annotate(year=TruncYear('tanggal')) \
                .values('year', 'id_lokasi__site') \
                .annotate(manual=Sum('manual'), masalah=Sum('masalah')) \
                .order_by('year')

            # Prepare the response data grouped by location (site_name)
            location_data = {}
            for location in locations:
                site_name = location.site
                location_data[site_name] = []

                location_parkir_data = [item for item in parkir_data if item['id_lokasi__site'] == site_name]
                for date in location_parkir_data:
                    date_value = date['year']
                    cash = Decimal(date['cash'] or 0)
                    prepaid = Decimal(date['prepaid'] or 0)
                    member = Decimal(next((item['member'] for item in member_data if item['year'] == date_value and item['id_lokasi__site'] == site_name), 0))
                    manual = Decimal(next((item['manual'] for item in manual_data if item['year'] == date_value and item['id_lokasi__site'] == site_name), 0))
                    masalah = Decimal(next((item['masalah'] for item in manual_data if item['year'] == date_value and item['id_lokasi__site'] == site_name), 0))

                    total = cash + prepaid + manual + member - masalah

                    location_data[site_name].append({
                        'tanggal': date_value.year,
                        'cash': cash,
                        'prepaid': prepaid,
                        'member': member,
                        'manual': manual,
                        'masalah': masalah,
                        'total': total
                    })

            return Response(location_data, status=200)

        except Exception as e:
            return Response({"status": "error", "message": f"Error in view_by_locations: {str(e)}"}, status=500)